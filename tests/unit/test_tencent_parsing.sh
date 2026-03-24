#!/usr/bin/env bash
# 测试腾讯接口响应字段提取

describe "腾讯响应字段提取"

# 从 fixture 读取数据
fixture=$(cat "$FIXTURES_DIR/tencent_stock.txt")

# 提取 full_code
full_code=$(echo "$fixture" | grep -o 'v_[a-z]*[0-9]*' | sed 's/v_//')
assert_eq "$full_code" "sh600519" "提取代码: sh600519"

# 提取引号内的数据部分
data=$(echo "$fixture" | cut -d'"' -f2)

# 以 ~ 分隔
IFS='~' read -ra fields <<< "$data"

assert_eq "${fields[1]}" "贵州茅台" "字段[1] 名称: 贵州茅台"
assert_eq "${fields[2]}" "600519" "字段[2] 代码: 600519"

assert_not_empty "${fields[3]}" "字段[3] 最新价: 非空"
assert_regex "${fields[3]}" '^[0-9]+\.[0-9]+$' "字段[3] 最新价: 数字格式"

assert_not_empty "${fields[4]}" "字段[4] 昨收: 非空"
assert_regex "${fields[4]}" '^[0-9]+\.[0-9]+$' "字段[4] 昨收: 数字格式"

assert_not_empty "${fields[5]}" "字段[5] 今开: 非空"

assert_not_empty "${fields[6]}" "字段[6] 成交量: 非空"
assert_regex "${fields[6]}" '^[0-9]+$' "字段[6] 成交量: 整数格式"

# 日期时间: YYYYMMDDHHMMSS（字段[30]，注意[29]为空字段）
assert_regex "${fields[30]}" '^[0-9]{14}$' "字段[30] 日期时间: 14位数字格式"

# 涨跌额
assert_not_empty "${fields[31]}" "字段[31] 涨跌额: 非空"
assert_regex "${fields[31]}" '^-?[0-9]+\.[0-9]+$' "字段[31] 涨跌额: 数字格式"

# 涨跌幅
assert_not_empty "${fields[32]}" "字段[32] 涨跌幅: 非空"
assert_regex "${fields[32]}" '^-?[0-9]+\.[0-9]+$' "字段[32] 涨跌幅: 数字格式"

# 最高/最低
assert_not_empty "${fields[33]}" "字段[33] 最高: 非空"
assert_not_empty "${fields[34]}" "字段[34] 最低: 非空"

# 批量响应：每行一个标的
describe "腾讯批量响应解析"

batch_fixture=$(cat "$FIXTURES_DIR/tencent_batch.txt")
line_count=$(echo "$batch_fixture" | grep -c 'v_')
assert_eq "$line_count" "3" "批量响应包含 3 行"

# 验证每行都能提取出名称
while IFS= read -r line; do
  [[ -z "$line" ]] && continue
  line_data=$(echo "$line" | cut -d'"' -f2)
  IFS='~' read -ra lf <<< "$line_data"
  line_name="${lf[1]:-}"
  assert_not_empty "$line_name" "批量行 名称非空: $line_name"
done <<< "$batch_fixture"
