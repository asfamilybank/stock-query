#!/usr/bin/env bash
# 接口可用性监控脚本
# 建议在每个交易日 15:30 后运行，检测数据源是否正常
# 用法: ./monitor.sh

set -uo pipefail

TIMEOUT=5
FAIL=0
TOTAL=0

CN_CODES=("sh600519" "sh510300" "sz000001" "sh518880" "sh512890")
HK_CODES=("hk00700" "hk09988")
US_CODES=("usAAPL" "usTSLA" "us.DJI")
FUND_CODES=("110011" "005827" "001549")

echo "=============================="
echo " 数据源可用性监控"
echo " $(date '+%Y-%m-%d %H:%M:%S')"
echo "=============================="
echo ""

echo "--- A股（腾讯财经·首选）---"
for code in "${CN_CODES[@]}"; do
  TOTAL=$((TOTAL + 1))
  result=$(curl -s -m $TIMEOUT "https://qt.gtimg.cn/q=${code}" | iconv -f GBK -t UTF-8 2>/dev/null)

  if [[ -z "$result" ]] || [[ "$result" == *'=""'* ]]; then
    echo "[FAIL] ${code} 返回空"
    FAIL=$((FAIL + 1))
  else
    data=$(echo "$result" | cut -d'"' -f2)
    IFS='~' read -ra fields <<< "$data"
    name="${fields[1]:-}"
    price="${fields[3]:-}"
    datetime="${fields[30]:-}"
    if [[ -n "$name" && -n "$price" ]]; then
      echo "[OK]   ${code} | ${name} | ${price} | ${datetime}"
    else
      echo "[FAIL] ${code} 字段解析失败"
      FAIL=$((FAIL + 1))
      TOTAL=$((TOTAL - 1))
    fi
  fi
done

echo ""
echo "--- 港股（腾讯财经）---"
for code in "${HK_CODES[@]}"; do
  TOTAL=$((TOTAL + 1))
  result=$(curl -s -m $TIMEOUT "https://qt.gtimg.cn/q=${code}" | iconv -f GBK -t UTF-8 2>/dev/null)

  if [[ -z "$result" ]] || [[ "$result" == *'=""'* ]]; then
    echo "[FAIL] ${code} 返回空"
    FAIL=$((FAIL + 1))
  else
    data=$(echo "$result" | cut -d'"' -f2)
    IFS='~' read -ra fields <<< "$data"
    name="${fields[1]:-}"
    price="${fields[3]:-}"
    datetime="${fields[30]:-}"
    if [[ -n "$name" && -n "$price" ]]; then
      echo "[OK]   ${code} | ${name} | ${price} | ${datetime}"
    else
      echo "[FAIL] ${code} 字段解析失败"
      FAIL=$((FAIL + 1))
      TOTAL=$((TOTAL - 1))
    fi
  fi
done

echo ""
echo "--- 美股（腾讯财经）---"
for code in "${US_CODES[@]}"; do
  TOTAL=$((TOTAL + 1))
  result=$(curl -s -m $TIMEOUT "https://qt.gtimg.cn/q=${code}" | iconv -f GBK -t UTF-8 2>/dev/null)

  if [[ -z "$result" ]] || [[ "$result" == *'=""'* ]]; then
    echo "[FAIL] ${code} 返回空"
    FAIL=$((FAIL + 1))
  else
    data=$(echo "$result" | cut -d'"' -f2)
    IFS='~' read -ra fields <<< "$data"
    name="${fields[1]:-}"
    price="${fields[3]:-}"
    datetime="${fields[30]:-}"
    if [[ -n "$name" && -n "$price" ]]; then
      echo "[OK]   ${code} | ${name} | ${price} | ${datetime}"
    else
      echo "[FAIL] ${code} 字段解析失败"
      FAIL=$((FAIL + 1))
      TOTAL=$((TOTAL - 1))
    fi
  fi
done

echo ""
echo "--- A股（新浪财经·备用）---"
for code in "${CN_CODES[@]}"; do
  TOTAL=$((TOTAL + 1))
  result=$(curl -s -m $TIMEOUT "https://hq.sinajs.cn/list=${code}" \
    -H "Referer: https://finance.sina.com.cn" | iconv -f GBK -t UTF-8 2>/dev/null)

  if [[ "$result" == *'=""'* ]] || [[ -z "$result" ]]; then
    echo "[FAIL] ${code} 返回空"
    FAIL=$((FAIL + 1))
  else
    name=$(echo "$result" | cut -d'"' -f2 | cut -d',' -f1)
    price=$(echo "$result" | cut -d'"' -f2 | cut -d',' -f4)
    date=$(echo "$result" | cut -d'"' -f2 | cut -d',' -f31)
    echo "[OK]   ${code} | ${name} | ${price} | ${date}"
  fi
done

echo ""
echo "--- 场外基金（天天基金）---"
for fc in "${FUND_CODES[@]}"; do
  TOTAL=$((TOTAL + 1))
  result=$(curl -s -m $TIMEOUT "http://fundgz.1234567.com.cn/js/${fc}.js")

  if [[ "$result" == "jsonpgz()" ]] || [[ -z "$result" ]]; then
    echo "[FAIL] fund_${fc} 返回空"
    FAIL=$((FAIL + 1))
  else
    name=$(echo "$result" | grep -o '"name":"[^"]*"' | cut -d'"' -f4)
    dwjz=$(echo "$result" | grep -o '"dwjz":"[^"]*"' | cut -d'"' -f4)
    jzrq=$(echo "$result" | grep -o '"jzrq":"[^"]*"' | cut -d'"' -f4)
    echo "[OK]   fund_${fc} | ${name} | 净值${dwjz} | ${jzrq}"
  fi
done

echo ""
echo "--- 备用接口（东方财富）---"
TOTAL=$((TOTAL + 1))
backup_result=$(curl -s -m $TIMEOUT \
  "https://api.fund.eastmoney.com/f10/lsjz?fundCode=110011&pageIndex=1&pageSize=1" \
  -H "Referer: https://fund.eastmoney.com" 2>/dev/null)

if [[ -z "$backup_result" ]] || [[ "$backup_result" == *"error"* ]]; then
  echo "[FAIL] 东方财富净值 API 不可用"
  FAIL=$((FAIL + 1))
else
  echo "[OK]   东方财富净值 API 可用"
fi

echo ""
echo "=============================="
PASS=$((TOTAL - FAIL))
if [[ $FAIL -eq 0 ]]; then
  echo "结果: 全部通过 (${PASS}/${TOTAL})"
else
  echo "结果: ${FAIL} 项失败 (${PASS}/${TOTAL} 通过)"
fi
echo "=============================="
