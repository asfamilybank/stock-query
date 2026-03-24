#!/usr/bin/env bash
# 测试输入校验（对应 query_price.sh 输入分类逻辑）

describe "输入校验"

QUERY_SCRIPT="$PROJECT_ROOT/scripts/query_price.sh"

# 复现校验逻辑
validate_code() {
  local code="$1"
  # 美股指数
  if [[ "$code" =~ ^\.[A-Z]+$ ]]; then return 0; fi
  # 美股 ticker
  if [[ "$code" =~ ^[A-Za-z] ]]; then return 0; fi
  # 港股 5 位
  if [[ "$code" =~ ^[0-9]{5}$ ]]; then return 0; fi
  # A 股 6 位
  if [[ "$code" =~ ^[0-9]{6}$ ]]; then return 0; fi
  echo "[ERROR] 无效代码: ${code}（A股6位/港股5位/美股英文ticker）"
  return 1
}

# A 股 6 位代码
output=$(validate_code "600519" 2>&1)
assert_exit_code $? 0 "600519（A股）→ 通过"

# 港股 5 位代码
output=$(validate_code "00700" 2>&1)
assert_exit_code $? 0 "00700（港股）→ 通过"

# 美股 ticker
output=$(validate_code "AAPL" 2>&1)
assert_exit_code $? 0 "AAPL（美股）→ 通过"

# 美股指数
output=$(validate_code ".DJI" 2>&1)
assert_exit_code $? 0 ".DJI（美股指数）→ 通过"

# 3 位数字 → 错误
output=$(validate_code "123" 2>&1)
assert_exit_code $? 1 "123（3位）→ 失败"
assert_contains "$output" "[ERROR]" "3位代码输出含 [ERROR]"

# 空输入 → 错误
output=$(validate_code "" 2>&1)
assert_exit_code $? 1 "空输入 → 失败"

# 7 位数字 → 错误
output=$(validate_code "1234567" 2>&1)
assert_exit_code $? 1 "1234567（7位）→ 失败"

# 4 位数字 → 错误（不是港股5位也不是A股6位）
output=$(validate_code "1234" 2>&1)
assert_exit_code $? 1 "1234（4位）→ 失败"

# 实际脚本调用测试
describe "query_price.sh 无效代码输出"

script_output=$("$QUERY_SCRIPT" 123 2>&1 || true)
assert_contains "$script_output" "[ERROR]" "query_price.sh 123 → 输出 [ERROR]"
assert_contains "$script_output" "无效代码" "query_price.sh 123 → 输出 无效代码"
