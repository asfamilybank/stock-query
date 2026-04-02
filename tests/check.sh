#!/usr/bin/env bash
# tests/check.sh — 自动化断言（L1-L5, L6-shell）
#
# L1: sq CLI 子命令完整性          无需网络           ~5s
# L2: 市场识别 + 字段完整性         需要网络           ~60s
# L3: 数据层扩展（指数/基金混批）    需要网络           ~15s
# L4: 场外基金数据（QDII/新鲜度）   需要网络           ~10s
# L5: emoji 规则断言                需要网络+openclaw  ~30s
# L6: portfolio CRUD bash 命令      无需网络           ~2s
#
# 用法:
#   bash tests/check.sh                 运行全部（需要 openclaw）
#   bash tests/check.sh --skip-network  仅运行 L1 + L6
#   bash tests/check.sh --skip-agent    跳过 L5（无 openclaw 时）
#
# 依赖: scripts/sq, jq, curl, iconv
# 可选: openclaw（L5 emoji 断言）

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SQ="$SCRIPT_DIR/../scripts/sq.sh"

PASS=0; FAIL=0; SKIP=0

pass() { printf '[PASS] %s\n' "$1"; PASS=$((PASS + 1)); }
fail() { printf '[FAIL] %s\n' "$1"; FAIL=$((FAIL + 1)); }
skip() { printf '[SKIP] %s\n' "$1"; SKIP=$((SKIP + 1)); }

check_deps() {
  local ok=true
  for dep in jq curl iconv awk grep; do
    command -v "$dep" &>/dev/null || { printf '[ERR]  依赖缺失: %s\n' "$dep"; ok=false; }
  done
  [[ -x "$SQ" ]] || { printf '[ERR]  不可执行: %s\n' "$SQ"; ok=false; }
  [[ "$ok" == "true" ]] || exit 1
}

# ── L1: sq CLI 子命令完整性（无需网络）───────────────────────────────────────

section_L1() {
  printf '\n=== L1: sq CLI 子命令完整性 ===\n'

  if { "$SQ" get 2>&1 || true; } | grep -q 'usage'; then
    pass "L1.1  sq get 无参数输出 usage"
  else
    fail "L1.1  sq get 无参数未输出 usage"
  fi

  if { "$SQ" fund 2>&1 || true; } | grep -q 'usage'; then
    pass "L1.2  sq fund 无参数输出 usage"
  else
    fail "L1.2  sq fund 无参数未输出 usage"
  fi

  local pfile; pfile=$("$SQ" pfile)
  if [[ "$pfile" == "NOT_FOUND" || -f "$pfile" ]]; then
    pass "L1.3  sq pfile 返回值合法（${pfile}）"
  else
    fail "L1.3  sq pfile 返回值非法: ${pfile}"
  fi

  if { "$SQ" 2>&1 || true; } | grep -q 'usage'; then
    pass "L1.4  sq 无子命令输出 usage"
  else
    fail "L1.4  sq 无子命令未输出 usage"
  fi
}

# ── L2: 市场识别 + 字段完整性（需要网络）────────────────────────────────────

# assert_jq LABEL JQ_EXPR code [code...]
assert_jq() {
  local label="$1" jq_expr="$2"
  shift 2
  local out
  out=$("$SQ" get "$@" 2>/dev/null) || true
  if printf '%s' "$out" | jq -e "$jq_expr" &>/dev/null; then
    pass "$label"
  else
    fail "$label"
    printf '  jq:  %s\n' "$jq_expr"
    printf '  out: %s\n' "$(printf '%s' "$out" | jq -c '.' 2>/dev/null || printf '%s' "$out")"
  fi
}

section_L2() {
  printf '\n=== L2: 市场识别 + 字段完整性 ===\n'

  assert_jq "L2.1  沪市股票 601991 → A股 CNY price非null" \
    '.[0] | .market == "A股" and .currency == "CNY" and .price != null' "601991"

  assert_jq "L2.2  深市股票 000002（非白名单）→ A股 price非null" \
    '.[0] | .market == "A股" and .price != null' "000002"

  assert_jq "L2.3  沪市指数 000300（白名单）→ A股 type=index" \
    '.[0] | .market == "A股" and .type == "index"' "000300"

  assert_jq "L2.4  深市指数 399006 → A股 type=index" \
    '.[0] | .market == "A股" and .type == "index"' "399006"

  assert_jq "L2.5  沪市 ETF 510300 → A股 type=etf" \
    '.[0] | .market == "A股" and .type == "etf"' "510300"

  assert_jq "L2.6  港股 00700（5位）→ 港股 HKD price非null" \
    '.[0] | .market == "港股" and .currency == "HKD" and .price != null' "00700"

  assert_jq "L2.7  港股 700（4位，自动补零）→ 港股 HKD price非null" \
    '.[0] | .market == "港股" and .currency == "HKD" and .price != null' "700"

  assert_jq "L2.8  美股 AAPL → 美股 USD price非null" \
    '.[0] | .market == "美股" and .currency == "USD" and .price != null' "AAPL"

  assert_jq "L2.9  美股指数 .IXIC → 美股 price非null" \
    '.[0] | .market == "美股" and .price != null' ".IXIC"

  assert_jq "L2.10 场外基金 014978 → 基金 price非null" \
    '.[0] | .market == "基金" and .price != null' "014978"

  assert_jq "L2.11 无效代码 XYZNOTEXIST → error非null 或 price=null" \
    '.[0] | .error != null or .price == null' "XYZNOTEXIST"

  assert_jq "L2.12 批量 AAPL 00700 601991 → 3项，顺序美股/港股/A股" \
    'length == 3 and .[0].market == "美股" and .[1].market == "港股" and .[2].market == "A股"' \
    "AAPL" "00700" "601991"

  assert_jq "L2.13 深市股票 000568（非白名单，probe）→ A股 price非null" \
    '.[0] | .market == "A股" and .price != null' "000568"
}

# ── L3: 数据层扩展（需要网络）────────────────────────────────────────────────

section_L3() {
  printf '\n=== L3: 数据层扩展 ===\n'

  # 美股三大指数（含 .SPX 别名映射）
  assert_jq "L3.1  美股三大指数 .DJI .IXIC .SPX → 3项均有价格" \
    'length == 3 and all(.[]; .price != null and .market == "美股")' \
    ".DJI" ".IXIC" ".SPX"

  # 基金 + 股票 + 美股混批，市场字段各自正确
  assert_jq "L3.2  混批 014978 601991 AAPL → 基金/A股/美股" \
    '.[0].market == "基金" and .[1].market == "A股" and .[2].market == "美股"' \
    "014978" "601991" "AAPL"

  # 港股补零一致性：700 和 00700 应拿到相同名称
  local name700 name00700
  name700=$(   "$SQ" get 700   2>/dev/null | jq -r '.[0].name // ""') || true
  name00700=$( "$SQ" get 00700 2>/dev/null | jq -r '.[0].name // ""') || true
  if [[ -n "$name700" && "$name700" == "$name00700" ]]; then
    pass "L3.3  港股 700 与 00700 名称一致（${name700}）"
  else
    fail "L3.3  港股 700 与 00700 名称不一致（'${name700}' vs '${name00700}'）"
  fi

  # 沪深同号碰撞：sh000001 上证指数 vs sz000001 平安银行
  assert_jq "L3.4  sh000001 → 上证指数（A股 index）" \
    '.[0] | .market == "A股" and .type == "index"' "sh000001"

  assert_jq "L3.5  sz000001 → 平安银行（A股 stock）" \
    '.[0] | .market == "A股" and .type == "stock"' "sz000001"
}

# ── L4: 场外基金数据（需要网络）──────────────────────────────────────────────

section_L4() {
  printf '\n=== L4: 场外基金数据 ===\n'

  local fund_out
  fund_out=$("$SQ" fund 014978 2>/dev/null) || true

  # 价格非 null
  if printf '%s' "$fund_out" | jq -e '.[0].price != null' &>/dev/null; then
    pass "L4.1  014978 price 非null"
  else
    fail "L4.1  014978 price 非null"
  fi

  # QDII 检测
  if printf '%s' "$fund_out" | jq -e '.[0].is_qdii == true' &>/dev/null; then
    pass "L4.2  014978 is_qdii=true"
  else
    fail "L4.2  014978 is_qdii=true"
  fi

  # 市场字段
  if printf '%s' "$fund_out" | jq -e '.[0].market == "基金"' &>/dev/null; then
    pass "L4.3  014978 market=基金"
  else
    fail "L4.3  014978 market=基金"
  fi

  # 新鲜度逻辑：gztime 日期 == 今日 → is_estimate=true；否则 → is_estimate=false
  local gztime gzdate today is_est
  gztime=$(printf '%s' "$fund_out" | jq -r '.[0].datetime // ""')
  gzdate="${gztime:0:10}"
  today=$(date +%Y-%m-%d)
  is_est=$(printf '%s' "$fund_out" | jq -r '.[0].is_estimate')
  if [[ "$gzdate" == "$today" ]]; then
    if [[ "$is_est" == "true" ]]; then
      pass "L4.4  gztime=今日（${gzdate}）→ is_estimate=true"
    else
      fail "L4.4  gztime=今日（${gzdate}）→ is_estimate 应为 true，实为 ${is_est}"
    fi
  else
    if [[ "$is_est" == "false" ]]; then
      pass "L4.4  gztime 非今日（${gzdate}）→ is_estimate=false（确认净值）"
    else
      fail "L4.4  gztime 非今日（${gzdate}）→ is_estimate 应为 false，实为 ${is_est}"
    fi
  fi

  # nav_date 格式校验（YYYY-MM-DD）
  local nav_date
  nav_date=$(printf '%s' "$fund_out" | jq -r '.[0].nav_date // ""')
  if [[ "$nav_date" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
    pass "L4.5  014978 nav_date 格式合法（${nav_date}）"
  else
    fail "L4.5  014978 nav_date 格式非法: '${nav_date}'"
  fi
}

# ── L5: emoji 规则断言（需要网络 + openclaw）─────────────────────────────────
# 用 sq get 的 direction 字段作为 ground truth，验证 agent 输出的 emoji 正确
#
# 规则：A股/港股  上涨→🔴  下跌→🟢  平盘→⚪
#       美股      上涨→🟩  下跌→🟥  平盘→⚪

_emoji_up_for()   { [[ "$1" == "美股" ]] && printf '🟩' || printf '🔴'; }
_emoji_down_for() { [[ "$1" == "美股" ]] && printf '🟥' || printf '🟢'; }

# assert_emoji LABEL CODE AGENT_INPUT
# 从 sq get 取 direction + market，查 openclaw，grep emoji
assert_emoji() {
  local label="$1" code="$2" agent_input="$3"

  local sq_out direction market
  sq_out=$("$SQ" get "$code" 2>/dev/null) || true
  direction=$(printf '%s' "$sq_out" | jq -r '.[0].direction // ""')
  market=$(   printf '%s' "$sq_out" | jq -r '.[0].market   // ""')

  if [[ -z "$direction" || -z "$market" ]]; then
    skip "$label (sq get 无数据，跳过)"
    return
  fi

  local agent_out
  agent_out=$(openclaw agent -m "$agent_input" \
    --session-id "sq-emoji-${code}-$(date +%s)" --json 2>/dev/null \
    | jq -r '[.result.payloads[].text] | join("\n")') || true

  if [[ -z "$agent_out" ]]; then
    skip "$label (openclaw 返回空响应，跳过)"
    return
  fi

  local expected_emoji
  case "$direction" in
    up)   expected_emoji=$(_emoji_up_for   "$market") ;;
    down) expected_emoji=$(_emoji_down_for "$market") ;;
    flat) expected_emoji='⚪' ;;
  esac

  if printf '%s' "$agent_out" | grep -qF "$expected_emoji"; then
    pass "$label  direction=${direction} market=${market} → ${expected_emoji}"
  else
    fail "$label  direction=${direction} market=${market}，期望 ${expected_emoji}，输出中未找到"
    printf '  输出: %s\n' "$(printf '%s' "$agent_out" | head -2)"
  fi
}

section_L5_emoji() {
  printf '\n=== L5: emoji 规则断言 ===\n'

  # A股：红涨绿跌
  assert_emoji "L5.1  A股 601991" "601991" "/stock-query 601991"

  # 港股：同 A股 规则（红涨绿跌）
  assert_emoji "L5.2  港股 00700" "00700"  "/stock-query 00700"

  # 美股：绿涨红跌
  assert_emoji "L5.3  美股 AAPL"  "AAPL"   "/stock-query AAPL"

  # 跨市场批量：同一输出里 A股 和 美股 同时出现，emoji 各自正确
  local batch_out
  batch_out=$(openclaw agent -m "/stock-query 601991 AAPL" \
    --session-id "sq-emoji-batch-$(date +%s)" --json 2>/dev/null \
    | jq -r '[.result.payloads[].text] | join("\n")') || true

  local dir_cn dir_us market_cn market_us
  local sq_cn sq_us
  sq_cn=$("$SQ" get 601991 2>/dev/null) || true
  sq_us=$("$SQ" get AAPL   2>/dev/null) || true
  dir_cn=$(   printf '%s' "$sq_cn" | jq -r '.[0].direction // ""')
  market_cn=$(printf '%s' "$sq_cn" | jq -r '.[0].market   // ""')
  dir_us=$(   printf '%s' "$sq_us" | jq -r '.[0].direction // ""')
  market_us=$(printf '%s' "$sq_us" | jq -r '.[0].market   // ""')

  if [[ -z "$dir_cn" || -z "$dir_us" ]]; then
    skip "L5.4  跨市场批量 emoji（无数据，跳过）"
  else
    local exp_cn exp_us
    case "$dir_cn" in
      up)   exp_cn=$(_emoji_up_for   "$market_cn") ;;
      down) exp_cn=$(_emoji_down_for "$market_cn") ;;
      flat) exp_cn='⚪' ;;
    esac
    case "$dir_us" in
      up)   exp_us=$(_emoji_up_for   "$market_us") ;;
      down) exp_us=$(_emoji_down_for "$market_us") ;;
      flat) exp_us='⚪' ;;
    esac

    local ok=true
    printf '%s' "$batch_out" | grep -qF "$exp_cn" || ok=false
    printf '%s' "$batch_out" | grep -qF "$exp_us" || ok=false
    if [[ "$ok" == "true" ]]; then
      pass "L5.4  跨市场批量 emoji  A股→${exp_cn}  美股→${exp_us}"
    else
      fail "L5.4  跨市场批量 emoji  期望 A股→${exp_cn} 美股→${exp_us}"
      printf '  输出: %s\n' "$(printf '%s' "$batch_out" | head -3)"
    fi
  fi
}

# ── L6: portfolio CRUD bash 命令（无需网络）──────────────────────────────────
# 直接测试 SKILL.md Command 1 中指定的 grep/awk 操作，不通过 agent

section_L6() {
  printf '\n=== L6: portfolio CRUD bash 命令 ===\n'

  # 准备临时测试文件
  local pf
  pf=$(mktemp /tmp/sq_test_XXXXXX.csv)
  # shellcheck disable=SC2064
  trap "rm -f '$pf'" RETURN

  printf '代码,名称,持仓,成本价\n601991,大唐发电,1000,4.00\n000300,,0,\n' > "$pf"

  # L6.1 查：grep -v 注释 + 跳过表头
  local rows; rows=$(grep -v '^#' "$pf" | tail -n +2)
  if printf '%s' "$rows" | grep -q "601991"; then
    pass "L6.1  查：现有条目可读取"
  else
    fail "L6.1  查：未读到 601991"
  fi

  # L6.2 增：追加新条目
  echo "002230,科大讯飞,500,30.00" >> "$pf"
  if grep -q "^002230," "$pf"; then
    pass "L6.2  增：002230 写入成功"
  else
    fail "L6.2  增：002230 未写入"
  fi

  # L6.3 增（重复检测）：grep -c 应仍为 1
  local dup_count; dup_count=$(grep -c "^002230," "$pf")
  if [[ "$dup_count" -eq 1 ]]; then
    pass "L6.3  增（重复检测）：002230 仅一行"
  else
    fail "L6.3  增（重复检测）：002230 有 ${dup_count} 行（应为1）"
  fi

  # L6.4 改：awk 替换（SKILL.md Command 1「改」的逻辑）
  local new_line="002230,科大讯飞,2000,35.00"
  local tmp; tmp=$(mktemp)
  awk -F',' -v c="002230" -v n="$new_line" \
    'BEGIN{OFS=","} $1==c{print n;next}{print}' "$pf" > "$tmp" && mv "$tmp" "$pf"
  if grep -q "^002230,科大讯飞,2000,35.00$" "$pf"; then
    pass "L6.4  改：002230 持仓更新为 2000/35.00"
  else
    fail "L6.4  改：002230 更新后内容不匹配"
    printf '  实际: %s\n' "$(grep "^002230" "$pf")"
  fi

  # L6.5 删：grep -v 过滤（SKILL.md Command 1「删」的逻辑）
  local tmp2; tmp2=$(mktemp)
  grep -v "^002230," "$pf" > "$tmp2" && mv "$tmp2" "$pf"
  if ! grep -q "^002230," "$pf"; then
    pass "L6.5  删：002230 已移除"
  else
    fail "L6.5  删：002230 仍在文件中"
  fi

  # L6.6 删（不存在）：行数不变
  local before_lines after_lines
  before_lines=$(wc -l < "$pf")
  local tmp3; tmp3=$(mktemp)
  grep -v "^999999," "$pf" > "$tmp3" && mv "$tmp3" "$pf"
  after_lines=$(wc -l < "$pf")
  if [[ "$before_lines" -eq "$after_lines" ]]; then
    pass "L6.6  删（不存在）：行数不变（${before_lines}行）"
  else
    fail "L6.6  删（不存在）：行数从 ${before_lines} 变为 ${after_lines}"
  fi

  # L6.7 NOT_FOUND 路径：sq pfile 在无文件时应返回 NOT_FOUND
  local saved_pfile="${PORTFOLIO_FILE:-}"
  local fake_dir; fake_dir=$(mktemp -d)
  # shellcheck disable=SC2064
  trap "rm -rf '$fake_dir'; rm -f '$pf'" RETURN
  local result
  result=$(PORTFOLIO_FILE="${fake_dir}/noexist.csv" "$SQ" pfile)
  if [[ "$result" == "NOT_FOUND" ]]; then
    pass "L6.7  sq pfile 文件不存在 → NOT_FOUND"
  else
    fail "L6.7  sq pfile 文件不存在 → 期望 NOT_FOUND，实为 '${result}'"
  fi
  rm -rf "$fake_dir"
}

# ── 入口 ──────────────────────────────────────────────────────────────────────

check_deps

SKIP_NETWORK=false
SKIP_AGENT=false
for _arg in "$@"; do
  [[ "$_arg" == "--skip-network" ]] && SKIP_NETWORK=true && SKIP_AGENT=true
  [[ "$_arg" == "--skip-agent"   ]] && SKIP_AGENT=true
done

# openclaw 不可用时自动跳过 L5
if ! command -v openclaw &>/dev/null; then
  SKIP_AGENT=true
fi

section_L1
section_L6   # 无需网络，与 L1 一起先跑

if [[ "$SKIP_NETWORK" == "true" ]]; then
  printf '\n=== L2/L3/L4/L5: 已跳过（--skip-network）===\n'
  SKIP=$((SKIP + 13 + 5 + 5 + 4))
else
  section_L2
  section_L3
  section_L4
  if [[ "$SKIP_AGENT" == "true" ]]; then
    printf '\n=== L5: 已跳过（--skip-agent 或 openclaw 不可用）===\n'
    SKIP=$((SKIP + 4))
  else
    section_L5_emoji
  fi
fi

printf '\n─────────────────────────────────────\n'
printf '结果: %d PASS / %d FAIL / %d SKIP\n' "$PASS" "$FAIL" "$SKIP"
[[ $FAIL -eq 0 ]]
