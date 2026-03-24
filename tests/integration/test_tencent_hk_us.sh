#!/usr/bin/env bash
# 测试腾讯财经 API 港股/美股查询

TIMEOUT="${INTEGRATION_TIMEOUT:-10}"
TEST_HK="${TEST_HK_STOCK:-00700}"
TEST_US="${TEST_US_STOCK:-AAPL}"
TEST_US_IDX="${TEST_US_INDEX:-.DJI}"

describe "腾讯财经 API — 港股"

if skip_if_no_network "腾讯 API 连通性"; then
  return 0 2>/dev/null || exit 0
fi

response=$(curl -s -m "$TIMEOUT" "https://qt.gtimg.cn/q=hk${TEST_HK}" \
  | iconv -f GBK -t UTF-8 2>/dev/null)

assert_not_empty "$response" "hk${TEST_HK} 响应非空"
assert_contains "$response" "v_hk${TEST_HK}" "响应包含 v_hk${TEST_HK} 前缀"

# 验证字段
data=$(echo "$response" | cut -d'"' -f2)
IFS='~' read -ra fields <<< "$data"
assert_eq "${fields[0]}" "100" "市场标识 [0]=100（港股）"
assert_not_empty "${fields[1]}" "名称非空: ${fields[1]:-}"
assert_regex "${fields[3]}" '^[0-9]+\.[0-9]+$' "最新价为数字: ${fields[3]:-}"
assert_not_empty "${fields[30]}" "日期时间非空"
assert_regex "${fields[32]}" '^-?[0-9]+\.[0-9]+$' "涨跌幅为数字: ${fields[32]:-}"

describe "腾讯财经 API — 美股"

response_us=$(curl -s -m "$TIMEOUT" "https://qt.gtimg.cn/q=us${TEST_US}" \
  | iconv -f GBK -t UTF-8 2>/dev/null)

assert_not_empty "$response_us" "us${TEST_US} 响应非空"
assert_contains "$response_us" "v_us${TEST_US}" "响应包含 v_us${TEST_US} 前缀"

data_us=$(echo "$response_us" | cut -d'"' -f2)
IFS='~' read -ra fields_us <<< "$data_us"
assert_eq "${fields_us[0]}" "200" "市场标识 [0]=200（美股）"
assert_not_empty "${fields_us[1]}" "名称非空: ${fields_us[1]:-}"
assert_regex "${fields_us[3]}" '^[0-9]+\.[0-9]+$' "最新价为数字: ${fields_us[3]:-}"

describe "腾讯财经 API — 美股指数"

response_idx=$(curl -s -m "$TIMEOUT" "https://qt.gtimg.cn/q=us${TEST_US_IDX}" \
  | iconv -f GBK -t UTF-8 2>/dev/null)

assert_not_empty "$response_idx" "us${TEST_US_IDX} 响应非空"

data_idx=$(echo "$response_idx" | cut -d'"' -f2)
IFS='~' read -ra fields_idx <<< "$data_idx"
assert_eq "${fields_idx[0]}" "200" "市场标识 [0]=200（美股指数）"
assert_not_empty "${fields_idx[1]}" "名称非空: ${fields_idx[1]:-}"
assert_regex "${fields_idx[3]}" '^[0-9]+\.[0-9]+$' "最新价为数字: ${fields_idx[3]:-}"

describe "腾讯财经 API — 跨市场批量查询"

batch=$(curl -s -m "$TIMEOUT" "https://qt.gtimg.cn/q=sh600519,hk${TEST_HK},us${TEST_US}" \
  | iconv -f GBK -t UTF-8 2>/dev/null)

assert_contains "$batch" "v_sh600519" "批量含 A 股 sh600519"
assert_contains "$batch" "v_hk${TEST_HK}" "批量含港股 hk${TEST_HK}"
assert_contains "$batch" "v_us${TEST_US}" "批量含美股 us${TEST_US}"
