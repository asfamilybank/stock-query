#!/usr/bin/env bash
# 测试 query_price.sh 批量查询（含跨市场）

QUERY_SCRIPT="$PROJECT_ROOT/scripts/query_price.sh"

describe "query_price.sh A 股批量查询"

if skip_if_no_network "批量查询需网络"; then
  return 0 2>/dev/null || exit 0
fi

# 正常批量查询：一个沪市股票 + 一个 ETF
output=$("$QUERY_SCRIPT" 600519 518880 2>&1)
exit_code=$?

assert_exit_code "$exit_code" 0 "exit code 0"
assert_contains "$output" "股票/ETF 行情" "输出含 股票/ETF 行情 标题"
assert_contains "$output" "600519" "输出含 sh600519"
assert_contains "$output" "518880" "输出含 sh518880"

# 验证每行都有管道分隔的字段
result_lines=$(echo "$output" | grep '|' | wc -l | tr -d ' ')
assert_gt "$result_lines" "1" "输出含 >1 行管道分隔结果"

describe "query_price.sh 混合查询（A 股 + 基金）"

mixed_output=$("$QUERY_SCRIPT" 600519 005827 2>&1)
mixed_exit=$?

assert_exit_code "$mixed_exit" 0 "混合查询 exit code 0"
assert_contains "$mixed_output" "股票/ETF 行情" "混合查询含股票部分"
assert_contains "$mixed_output" "基金" "混合查询含基金部分"

describe "query_price.sh 港股/美股查询"

global_output=$("$QUERY_SCRIPT" 00700 AAPL 2>&1)
global_exit=$?

assert_exit_code "$global_exit" 0 "港股/美股查询 exit code 0"
assert_contains "$global_output" "股票/ETF 行情" "输出含行情标题"
assert_contains "$global_output" "00700" "输出含港股 00700"
assert_contains "$global_output" "AAPL" "输出含美股 AAPL"
assert_contains "$global_output" "港股" "输出含 港股 标签"
assert_contains "$global_output" "美股" "输出含 美股 标签"

describe "query_price.sh 跨市场混合查询"

cross_output=$("$QUERY_SCRIPT" 600519 00700 AAPL .DJI 2>&1)
cross_exit=$?

assert_exit_code "$cross_exit" 0 "跨市场查询 exit code 0"
assert_contains "$cross_output" "600519" "含 A 股"
assert_contains "$cross_output" "00700" "含港股"
assert_contains "$cross_output" "AAPL" "含美股"
assert_contains "$cross_output" ".DJI" "含美股指数"

describe "query_price.sh 无参数"

no_arg_output=$("$QUERY_SCRIPT" 2>&1)
no_arg_exit=$?
assert_exit_code "$no_arg_exit" 0 "无参数 exit code 0"
