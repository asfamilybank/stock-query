#!/usr/bin/env bash
# 测试腾讯财经 API 真实调用（首选数据源）

TIMEOUT="${INTEGRATION_TIMEOUT:-10}"
TEST_SH="${TEST_STOCK_SH:-600519}"
TEST_SZ="${TEST_STOCK_SZ:-000001}"

describe "腾讯财经 API — 沪市股票"

if skip_if_no_network "腾讯 API 连通性"; then
  return 0 2>/dev/null || exit 0
fi

response=$(curl -s -m "$TIMEOUT" "https://qt.gtimg.cn/q=sh${TEST_SH}" \
  | iconv -f GBK -t UTF-8 2>/dev/null)

assert_not_empty "$response" "sh${TEST_SH} 响应非空"
assert_contains "$response" "v_sh${TEST_SH}" "响应包含 v_sh${TEST_SH} 前缀"

# 验证 ~ 分隔字段
data=$(echo "$response" | cut -d'"' -f2)
field_count=$(echo "$data" | tr '~' '\n' | wc -l | tr -d ' ')
assert_gt "$field_count" "30" "字段数 > 30（实际: ${field_count}）"

# 名称为有效 UTF-8
IFS='~' read -ra fields <<< "$data"
name="${fields[1]:-}"
assert_not_empty "$name" "名称字段非空: ${name}"

# 最新价为有效数字
latest="${fields[3]:-}"
assert_regex "$latest" '^[0-9]+\.[0-9]+$' "最新价为数字: ${latest}"

# 涨跌幅已预计算（字段[32]）
change_pct="${fields[32]:-}"
assert_regex "$change_pct" '^-?[0-9]+\.[0-9]+$' "涨跌幅为数字: ${change_pct}"

describe "腾讯财经 API — 深市股票"

response_sz=$(curl -s -m "$TIMEOUT" "https://qt.gtimg.cn/q=sz${TEST_SZ}" \
  | iconv -f GBK -t UTF-8 2>/dev/null)

assert_not_empty "$response_sz" "sz${TEST_SZ} 响应非空"
assert_contains "$response_sz" "v_sz${TEST_SZ}" "响应包含 v_sz${TEST_SZ} 前缀"

describe "腾讯财经 API — 批量查询"

batch_response=$(curl -s -m "$TIMEOUT" "https://qt.gtimg.cn/q=sh${TEST_SH},sz${TEST_SZ}" \
  | iconv -f GBK -t UTF-8 2>/dev/null)

assert_contains "$batch_response" "v_sh${TEST_SH}" "批量含 sh${TEST_SH}"
assert_contains "$batch_response" "v_sz${TEST_SZ}" "批量含 sz${TEST_SZ}"

describe "腾讯财经 API — 无效代码"

response_invalid=$(curl -s -m "$TIMEOUT" "https://qt.gtimg.cn/q=sz999999" \
  | iconv -f GBK -t UTF-8 2>/dev/null)

# 腾讯对无效代码返回空引号或极少字段
invalid_data=$(echo "$response_invalid" | cut -d'"' -f2)
invalid_fields=$(echo "$invalid_data" | tr '~' '\n' | wc -l | tr -d ' ')
# 无效代码字段数远少于正常响应（通常 <5 或为空）
if [[ "$invalid_fields" -lt 30 ]] || [[ -z "$invalid_data" ]]; then
  test_pass "无效代码 sz999999 返回空/少量数据（字段数: ${invalid_fields}）"
else
  test_fail "无效代码 sz999999 应返回空数据" "实际字段数: ${invalid_fields}"
fi
