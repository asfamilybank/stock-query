#!/usr/bin/env bash
# tests/datasource_check.sh
# L0 数据源存活检测 — 验证 stock-query 依赖的 5 个上游 API 可达且返回可解析数据
# 用法：bash tests/datasource_check.sh
# 退出码：0=全部通过，1=有失败

set -euo pipefail

PASS=0
FAIL=0
RESULTS=()

check() {
  local name="$1"
  local result="$2"  # "ok" or "fail: <reason>"
  if [ "$result" = "ok" ]; then
    echo "[OK]   $name"
    RESULTS+=("PASS|$name")
    PASS=$((PASS + 1))
  else
    echo "[FAIL] $name — ${result#fail: }"
    RESULTS+=("FAIL|$name|${result#fail: }")
    FAIL=$((FAIL + 1))
  fi
}

run_check() {
  local name="$1"
  shift
  local result
  result=$("$@" 2>&1) || true
  echo "$result"
}

echo "=============================="
echo "stock-query 数据源存活检测 (L0)"
echo "=============================="
echo ""

# ── DS-1: 腾讯财经 A股 ──────────────────────────────────────────────────────
name="DS-1 腾讯财经 A股 (qt.gtimg.cn)"
raw=$(curl -s --max-time 8 "https://qt.gtimg.cn/q=sh601991" | iconv -f GBK -t UTF-8 2>/dev/null || echo "")
if echo "$raw" | grep -qE 'v_sh601991="[^~]'; then
  # 提取名称字段（索引1）验证非空
  name_field=$(echo "$raw" | sed 's/.*="\(.*\)".*/\1/' | cut -d'~' -f2)
  if [ -n "$name_field" ]; then
    check "$name" "ok"
  else
    check "$name" "fail: 响应格式异常，名称字段为空"
  fi
else
  check "$name" "fail: 无法获取有效响应（raw: ${raw:0:80}）"
fi

# ── DS-2: 腾讯财经 港股 ──────────────────────────────────────────────────────
name="DS-2 腾讯财经 港股 (qt.gtimg.cn, hk00700)"
raw=$(curl -s --max-time 8 "https://qt.gtimg.cn/q=hk00700" | iconv -f GBK -t UTF-8 2>/dev/null || echo "")
if echo "$raw" | grep -qE 'v_hk00700="[^~]'; then
  check "$name" "ok"
else
  check "$name" "fail: 无法获取有效响应（raw: ${raw:0:80}）"
fi

# ── DS-3: 腾讯财经 美股 ──────────────────────────────────────────────────────
name="DS-3 腾讯财经 美股 (qt.gtimg.cn, usAAPL)"
raw=$(curl -s --max-time 8 "https://qt.gtimg.cn/q=usAAPL" | iconv -f GBK -t UTF-8 2>/dev/null || echo "")
if echo "$raw" | grep -qE 'v_usAAPL="[^~]'; then
  check "$name" "ok"
else
  check "$name" "fail: 无法获取有效响应（raw: ${raw:0:80}）"
fi

# ── DS-4: 新浪财经 A股备用 ───────────────────────────────────────────────────
name="DS-4 新浪财经 A股备用 (hq.sinajs.cn)"
raw=$(curl -s --max-time 8 "https://hq.sinajs.cn/list=sh601991" \
  -H "Referer: https://finance.sina.com.cn" | iconv -f GBK -t UTF-8 2>/dev/null || echo "")
# 新浪响应格式：var hq_str_sh601991="名称,..."
if echo "$raw" | grep -qE 'hq_str_sh601991="[^"]+'; then
  check "$name" "ok"
else
  check "$name" "fail: 无法获取有效响应（raw: ${raw:0:80}）"
fi

# ── DS-5: 东方财富 港股备用 ──────────────────────────────────────────────────
name="DS-5 东方财富 港股备用 (push2.eastmoney.com, 116.00700)"
raw=$(curl -s --max-time 8 \
  "https://push2.eastmoney.com/api/qt/stock/get?secid=116.00700&fields=f43,f57,f58,f169,f170&fltt=2" \
  2>/dev/null || echo "")
if echo "$raw" | python3 -c "import sys,json; d=json.load(sys.stdin); assert d.get('data') is not None" 2>/dev/null; then
  check "$name" "ok"
elif echo "$raw" | grep -q '"f58"'; then
  check "$name" "ok"
else
  check "$name" "fail: 无法获取有效 JSON 或 data 为 null（raw: ${raw:0:120}）"
fi

# ── DS-6: 东方财富 美股备用 (NASDAQ) ─────────────────────────────────────────
name="DS-6 东方财富 美股备用 (push2.eastmoney.com, 105.AAPL)"
raw=$(curl -s --max-time 8 \
  "https://push2.eastmoney.com/api/qt/stock/get?secid=105.AAPL&fields=f43,f57,f58,f169,f170&fltt=2" \
  2>/dev/null || echo "")
if echo "$raw" | grep -q '"f58"'; then
  check "$name" "ok"
else
  check "$name" "fail: 无法获取有效 JSON（raw: ${raw:0:120}）"
fi

# ── DS-7: 天天基金估值 场外基金首选 ──────────────────────────────────────────
name="DS-7 天天基金估值 (fundgz.1234567.com.cn, 014978)"
raw=$(curl -s --max-time 8 "http://fundgz.1234567.com.cn/js/014978.js" 2>/dev/null || echo "")
# 响应格式：jsonpgz({...})
if echo "$raw" | grep -q '"fundcode"'; then
  check "$name" "ok"
else
  # 非交易日可能返回空 jsonpgz()，属正常降级，不算 FAIL
  if echo "$raw" | grep -q 'jsonpgz()'; then
    echo "       ⚠️  返回空估值（非交易时段或节假日），属正常现象"
    check "$name" "ok"
  else
    check "$name" "fail: 无法获取响应（raw: ${raw:0:80}）"
  fi
fi

# ── DS-8: 东方财富净值 场外基金备用 ──────────────────────────────────────────
name="DS-8 东方财富净值 (api.fund.eastmoney.com, 014978)"
raw=$(curl -s --max-time 8 \
  "https://api.fund.eastmoney.com/f10/lsjz?fundCode=014978&pageIndex=1&pageSize=1" \
  -H "Referer: https://fund.eastmoney.com" 2>/dev/null || echo "")
if echo "$raw" | grep -q '"DWJZ"'; then
  check "$name" "ok"
else
  check "$name" "fail: 无法获取有效净值数据（raw: ${raw:0:120}）"
fi

# ── 汇总 ─────────────────────────────────────────────────────────────────────
total=$(( PASS + FAIL ))
echo ""
echo "=============================="
printf "pass: %d / fail: %d (total: %d)\n" "${PASS}" "${FAIL}" "${total}"
echo "=============================="

if [ "${FAIL}" -gt 0 ]; then
  echo ""
  echo "FAILED:"
  for r in "${RESULTS[@]}"; do
    IFS='|' read -r _status _name _reason <<< "$r"
    if [ "${_status}" = "FAIL" ]; then
      echo "  - ${_name}: ${_reason:-}"
    fi
  done
  exit 1
fi

exit 0
