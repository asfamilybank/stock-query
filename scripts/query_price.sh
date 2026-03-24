#!/usr/bin/env bash
# 批量查询全球股票行情（A股/港股/美股/ETF/基金）
# 用法: ./query_price.sh 600519 00700 AAPL .DJI 110011
# 支持混合输入：6位数字(A股) / 5位数字(港股) / 英文(美股) / .XXX(美股指数)

set -euo pipefail

TENCENT_API="https://qt.gtimg.cn/q="
SINA_API="https://hq.sinajs.cn/list="
FUND_API="http://fundgz.1234567.com.cn/js/"
TIMEOUT=5

stock_list=""
fund_codes=()

for code in "$@"; do
  # 美股指数: .DJI, .IXIC, .SPX
  if [[ "$code" =~ ^\.[A-Z]+$ ]]; then
    stock_list="${stock_list:+$stock_list,}us${code}"
  # 美股 ticker: 纯英文或英文+数字
  elif [[ "$code" =~ ^[A-Za-z] ]]; then
    upper_code=$(echo "$code" | tr '[:lower:]' '[:upper:]')
    stock_list="${stock_list:+$stock_list,}us${upper_code}"
  # 港股: 5 位纯数字
  elif [[ "$code" =~ ^[0-9]{5}$ ]]; then
    stock_list="${stock_list:+$stock_list,}hk${code}"
  # A 股: 6 位纯数字
  elif [[ "$code" =~ ^[0-9]{6}$ ]]; then
    if [[ $code =~ ^6 ]]; then
      stock_list="${stock_list:+$stock_list,}sh${code}"
    elif [[ $code =~ ^[03] ]]; then
      # 先尝试腾讯接口判断是否为深市股票
      result=$(curl -s -m $TIMEOUT "https://qt.gtimg.cn/q=sz${code}" | iconv -f GBK -t UTF-8 2>/dev/null)
      tencent_data=$(echo "$result" | cut -d'"' -f2)
      IFS='~' read -ra probe_fields <<< "$tencent_data"
      if [[ -n "${probe_fields[1]:-}" && -n "${probe_fields[3]:-}" ]]; then
        stock_list="${stock_list:+$stock_list,}sz${code}"
      else
        # 腾讯无数据，回退新浪确认
        result=$(curl -s -m $TIMEOUT "https://hq.sinajs.cn/list=sz${code}" \
          -H "Referer: https://finance.sina.com.cn" | iconv -f GBK -t UTF-8 2>/dev/null)
        if [[ "$result" == *'=""'* ]] || [[ -z "$result" ]]; then
          fund_codes+=("$code")
        else
          stock_list="${stock_list:+$stock_list,}sz${code}"
        fi
      fi
    elif [[ $code =~ ^5 ]]; then
      stock_list="${stock_list:+$stock_list,}sh${code}"
    elif [[ $code =~ ^1 ]]; then
      stock_list="${stock_list:+$stock_list,}sz${code}"
    else
      fund_codes+=("$code")
    fi
  else
    echo "[ERROR] 无效代码: ${code}（A股6位/港股5位/美股英文ticker）"
    continue
  fi
done

parse_tencent_line() {
  local line="$1"
  [[ -z "$line" ]] && return 1
  local full_code data
  # 提取变量名: v_sh601991, v_hk00700, v_usAAPL, v_us.DJI
  full_code=$(echo "$line" | grep -oE 'v_[a-z]+[A-Za-z0-9.]+' | sed 's/v_//')
  data=$(echo "$line" | cut -d'"' -f2)
  [[ -z "$data" ]] && return 1

  # 腾讯接口字段以 ~ 分隔
  local IFS='~'
  read -ra fields <<< "$data"
  local market_id="${fields[0]:-}"
  local name="${fields[1]:-}"
  local latest="${fields[3]:-}"
  local change_pct="${fields[32]:-}"
  local datetime="${fields[30]:-}"

  [[ -z "$name" || -z "$latest" ]] && return 1

  # 日期时间格式化
  local fmt_date=""
  if [[ ${#datetime} -ge 14 ]] && [[ "$datetime" =~ ^[0-9]+$ ]]; then
    # A 股格式: YYYYMMDDHHMMSS
    fmt_date="${datetime:0:4}-${datetime:4:2}-${datetime:6:2} ${datetime:8:2}:${datetime:10:2}:${datetime:12:2}"
  else
    # 港股/美股已是可读格式
    fmt_date="$datetime"
  fi

  # 涨跌标识（区分市场惯例）
  local emoji sign
  local is_us=false
  [[ "$market_id" == "200" ]] && is_us=true

  if (( $(echo "${change_pct:-0} > 0" | bc -l 2>/dev/null || echo 0) )); then
    sign="+"
    if [[ "$is_us" == "true" ]]; then emoji="🟩"; else emoji="🔴"; fi
  elif (( $(echo "${change_pct:-0} < 0" | bc -l 2>/dev/null || echo 0) )); then
    sign=""
    if [[ "$is_us" == "true" ]]; then emoji="🟥"; else emoji="🟢"; fi
  else
    emoji="⚪"; sign=""
  fi
  local pct_fmt
  pct_fmt=$(printf "%.2f" "$change_pct" 2>/dev/null || echo "$change_pct")

  # 市场标签
  local market_label
  case "$market_id" in
    1|51) market_label="A股" ;;
    100)  market_label="港股" ;;
    200)  market_label="美股" ;;
    *)    market_label="—"   ;;
  esac

  echo "${full_code} | ${name} | ${market_label} | ${latest} | ${emoji} ${sign}${pct_fmt}% | ${fmt_date}"
  return 0
}

parse_sina_line() {
  local line="$1"
  [[ -z "$line" ]] && return 1
  local full_code data
  full_code=$(echo "$line" | grep -o 'str_[a-z]*[0-9]*' | sed 's/str_//')
  data=$(echo "$line" | cut -d'"' -f2)
  [[ -z "$data" ]] && return 1

  local name yesterday_close latest date time
  name=$(echo "$data" | cut -d',' -f1)
  yesterday_close=$(echo "$data" | cut -d',' -f3)
  latest=$(echo "$data" | cut -d',' -f4)
  date=$(echo "$data" | cut -d',' -f31)
  time=$(echo "$data" | cut -d',' -f32)

  if command -v bc &>/dev/null && [[ "$yesterday_close" != "0.000" ]]; then
    local change change_pct emoji sign
    change=$(echo "scale=4; $latest - $yesterday_close" | bc)
    change_pct=$(echo "scale=4; ($latest - $yesterday_close) / $yesterday_close * 100" | bc | xargs printf "%.2f")
    if (( $(echo "$change > 0" | bc -l) )); then
      emoji="🔴"; sign="+"
    elif (( $(echo "$change < 0" | bc -l) )); then
      emoji="🟢"; sign=""
    else
      emoji="⚪"; sign=""
    fi
    echo "${full_code} | ${name} | A股 | ${latest} | ${emoji} ${sign}${change_pct}% | ${date} ${time}"
  else
    echo "${full_code} | ${name} | A股 | ${latest} | ${date} ${time}"
  fi
  return 0
}

if [[ -n "$stock_list" ]]; then
  echo "=== 股票/ETF 行情 ==="
  use_sina=false

  # 首选：腾讯接口
  response=$(curl -s -m $TIMEOUT "${TENCENT_API}${stock_list}" | iconv -f GBK -t UTF-8 2>/dev/null)

  if [[ -z "$response" ]]; then
    echo "[INFO] 腾讯接口无响应，回退到新浪接口..."
    use_sina=true
  fi

  if [[ "$use_sina" == "false" ]]; then
    while IFS= read -r line; do
      [[ -z "$line" ]] && continue
      if ! parse_tencent_line "$line"; then
        echo "[WARN] 腾讯数据解析失败，回退到新浪接口..."
        use_sina=true
        break
      fi
    done <<< "$response"
  fi

  # 备用：新浪接口（仅 A 股部分）
  if [[ "$use_sina" == "true" ]]; then
    # 过滤出 A 股代码（sh/sz 开头）
    cn_list=$(echo "$stock_list" | tr ',' '\n' | grep -E '^(sh|sz)' | tr '\n' ',' | sed 's/,$//')
    hk_us_list=$(echo "$stock_list" | tr ',' '\n' | grep -vE '^(sh|sz)' | tr '\n' ',' | sed 's/,$//')

    if [[ -n "$cn_list" ]]; then
      response=$(curl -s -m $TIMEOUT "${SINA_API}${cn_list}" \
        -H "Referer: https://finance.sina.com.cn" | iconv -f GBK -t UTF-8 2>/dev/null)

      if [[ -z "$response" ]]; then
        echo "[ERROR] 新浪接口请求失败，正在重试..."
        sleep 1
        response=$(curl -s -m $TIMEOUT "${SINA_API}${cn_list}" \
          -H "Referer: https://finance.sina.com.cn" | iconv -f GBK -t UTF-8 2>/dev/null)
      fi

      if [[ -z "$response" ]]; then
        echo "[ERROR] A 股数据源均不可用，请稍后重试"
      else
        while IFS= read -r line; do
          [[ -z "$line" ]] && continue
          parse_sina_line "$line" || echo "[WARN] 解析失败: $line"
        done <<< "$response"
      fi
    fi

    if [[ -n "$hk_us_list" ]]; then
      echo "[ERROR] 港股/美股数据源（腾讯财经）不可用，请稍后重试"
    fi
  fi
  echo ""
fi

for fc in "${fund_codes[@]+"${fund_codes[@]}"}"; do
  [[ -z "$fc" ]] && continue
  echo "=== 基金 ${fc} ==="
  result=$(curl -s -m $TIMEOUT "${FUND_API}${fc}.js")

  if [[ "$result" == "jsonpgz()" ]] || [[ -z "$result" ]]; then
    echo "[ERROR] 未找到基金 ${fc}，请确认代码是否正确"
    continue
  fi

  name=$(echo "$result" | grep -o '"name":"[^"]*"' | cut -d'"' -f4)
  dwjz=$(echo "$result" | grep -o '"dwjz":"[^"]*"' | cut -d'"' -f4)
  gsz=$(echo "$result" | grep -o '"gsz":"[^"]*"' | cut -d'"' -f4)
  gszzl=$(echo "$result" | grep -o '"gszzl":"[^"]*"' | cut -d'"' -f4)
  gztime=$(echo "$result" | grep -o '"gztime":"[^"]*"' | cut -d'"' -f4)
  jzrq=$(echo "$result" | grep -o '"jzrq":"[^"]*"' | cut -d'"' -f4)

  if (( $(echo "$gszzl > 0" | bc -l 2>/dev/null || echo 0) )); then
    emoji="🔴"
    sign="+"
  elif (( $(echo "$gszzl < 0" | bc -l 2>/dev/null || echo 0) )); then
    emoji="🟢"
    sign=""
  else
    emoji="⚪"
    sign=""
  fi

  qdii_note=""
  if echo "$name" | grep -qiE "QDII|纳斯达克|标普|海外|美国|全球"; then
    qdii_note=" ⏳ QDII基金，净值有延迟"
  fi

  echo "fund_${fc} | ${name} | 净值${dwjz}(${jzrq}) | 估值${gsz} | ${emoji} ${sign}${gszzl}%（估）| ${gztime}${qdii_note}"
  echo ""
done
