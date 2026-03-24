#!/usr/bin/env bash
# 测试辅助函数库
# 所有 test_*.sh 文件通过 source 引入

# --- 颜色 ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
RESET='\033[0m'

# --- 计数器 ---
PASS=0
FAIL=0
SKIP=0

# --- 项目根目录 ---
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FIXTURES_DIR="${PROJECT_ROOT}/tests/fixtures"

# --- 断言函数 ---

assert_eq() {
  local actual="$1" expected="$2" desc="$3"
  if [[ "$actual" == "$expected" ]]; then
    test_pass "$desc"
  else
    test_fail "$desc" "expected: '${expected}', got: '${actual}'"
  fi
}

assert_contains() {
  local haystack="$1" needle="$2" desc="$3"
  if [[ "$haystack" == *"$needle"* ]]; then
    test_pass "$desc"
  else
    test_fail "$desc" "expected to contain: '${needle}'"
  fi
}

assert_not_contains() {
  local haystack="$1" needle="$2" desc="$3"
  if [[ "$haystack" != *"$needle"* ]]; then
    test_pass "$desc"
  else
    test_fail "$desc" "expected NOT to contain: '${needle}'"
  fi
}

assert_not_empty() {
  local value="$1" desc="$2"
  if [[ -n "$value" ]]; then
    test_pass "$desc"
  else
    test_fail "$desc" "expected non-empty value"
  fi
}

assert_empty() {
  local value="$1" desc="$2"
  if [[ -z "$value" ]]; then
    test_pass "$desc"
  else
    test_fail "$desc" "expected empty, got: '${value}'"
  fi
}

assert_exit_code() {
  local actual="$1" expected="$2" desc="$3"
  if [[ "$actual" -eq "$expected" ]]; then
    test_pass "$desc"
  else
    test_fail "$desc" "expected exit code ${expected}, got ${actual}"
  fi
}

assert_regex() {
  local value="$1" pattern="$2" desc="$3"
  if [[ "$value" =~ $pattern ]]; then
    test_pass "$desc"
  else
    test_fail "$desc" "expected to match regex: '${pattern}', got: '${value}'"
  fi
}

assert_gt() {
  local actual="$1" threshold="$2" desc="$3"
  if (( $(echo "$actual > $threshold" | bc -l 2>/dev/null) )); then
    test_pass "$desc"
  else
    test_fail "$desc" "expected > ${threshold}, got ${actual}"
  fi
}

# --- 输出函数 ---

test_pass() {
  local desc="$1"
  PASS=$((PASS + 1))
  printf "  ${GREEN}✓${RESET} %s\n" "$desc"
}

test_fail() {
  local desc="$1" detail="${2:-}"
  FAIL=$((FAIL + 1))
  printf "  ${RED}✗${RESET} %s\n" "$desc"
  if [[ -n "$detail" ]]; then
    printf "    ${RED}%s${RESET}\n" "$detail"
  fi
}

test_skip() {
  local desc="$1" reason="$2"
  SKIP=$((SKIP + 1))
  printf "  ${YELLOW}⊘${RESET} %s (SKIP: %s)\n" "$desc" "$reason"
}

describe() {
  local title="$1"
  printf "\n${CYAN}▸ %s${RESET}\n" "$title"
}

# --- 条件跳过 ---

is_trading_hours() {
  local dow current_time
  dow=$(TZ=Asia/Shanghai date +%u 2>/dev/null || date +%u)
  current_time=$(TZ=Asia/Shanghai date +%H%M 2>/dev/null || date +%H%M)

  # 周末
  if [[ "$dow" -ge 6 ]]; then
    return 1
  fi

  # 上午 9:30-11:30 或下午 13:00-15:00
  if { [[ "$current_time" -ge 930 ]] && [[ "$current_time" -le 1130 ]]; } ||
     { [[ "$current_time" -ge 1300 ]] && [[ "$current_time" -le 1500 ]]; }; then
    return 0
  fi

  return 1
}

check_market_hours() {
  local market_hours="${MARKET_HOURS:-auto}"
  case "$market_hours" in
    force_trading) return 0 ;;
    force_closed)  return 1 ;;
    *)             is_trading_hours ;;
  esac
}

skip_if_market_closed() {
  local desc="$1"
  if ! check_market_hours; then
    test_skip "$desc" "非交易时段"
    return 0
  fi
  return 1
}

skip_if_no_network() {
  local desc="$1"
  if ! curl -s --max-time 3 "https://qt.gtimg.cn" >/dev/null 2>&1 && \
     ! curl -s --max-time 3 "https://hq.sinajs.cn" >/dev/null 2>&1; then
    test_skip "$desc" "无网络连接"
    return 0
  fi
  return 1
}

# --- 汇总 ---

summary() {
  local total=$((PASS + FAIL + SKIP))
  echo ""
  echo "=============================="
  printf "  总计: %d | ${GREEN}通过: %d${RESET} | ${RED}失败: %d${RESET} | ${YELLOW}跳过: %d${RESET}\n" \
    "$total" "$PASS" "$FAIL" "$SKIP"
  echo "=============================="

  if [[ "$FAIL" -gt 0 ]]; then
    return 1
  fi
  return 0
}
