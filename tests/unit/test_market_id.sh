#!/usr/bin/env bash
# 测试市场识别逻辑（对应 query_price.sh 的输入分类）

describe "市场前缀识别 — A 股"

# 复现 A 股市场判断逻辑
identify_cn_market() {
  local code="$1"
  if [[ $code =~ ^6 ]]; then
    echo "sh:stock"
  elif [[ $code =~ ^[03] ]]; then
    echo "sz:stock_or_fund"
  elif [[ $code =~ ^5 ]]; then
    echo "sh:etf"
  elif [[ $code =~ ^1 ]]; then
    echo "sz:etf"
  else
    echo "fund"
  fi
}

# 沪市股票
assert_eq "$(identify_cn_market 600519)" "sh:stock" "600519 → sh:stock（贵州茅台）"
assert_eq "$(identify_cn_market 601991)" "sh:stock" "601991 → sh:stock（大唐发电）"
assert_eq "$(identify_cn_market 688981)" "sh:stock" "688981 → sh:stock（科创板）"

# 深市股票 / 可能是基金
assert_eq "$(identify_cn_market 000001)" "sz:stock_or_fund" "000001 → sz:stock_or_fund（平安银行）"
assert_eq "$(identify_cn_market 300750)" "sz:stock_or_fund" "300750 → sz:stock_or_fund（创业板）"
assert_eq "$(identify_cn_market 002594)" "sz:stock_or_fund" "002594 → sz:stock_or_fund（中小板）"

# 沪市 ETF
assert_eq "$(identify_cn_market 510300)" "sh:etf" "510300 → sh:etf（沪深300ETF）"
assert_eq "$(identify_cn_market 518880)" "sh:etf" "518880 → sh:etf（黄金ETF）"
assert_eq "$(identify_cn_market 563230)" "sh:etf" "563230 → sh:etf（卫星ETF）"

# 深市 ETF
assert_eq "$(identify_cn_market 159915)" "sz:etf" "159915 → sz:etf（创业板ETF）"
assert_eq "$(identify_cn_market 159919)" "sz:etf" "159919 → sz:etf（沪深300ETF深市）"

# 场外基金（2/4/7/8/9 开头）
assert_eq "$(identify_cn_market 210001)" "fund" "210001 → fund（2开头）"
assert_eq "$(identify_cn_market 400001)" "fund" "400001 → fund（4开头）"
assert_eq "$(identify_cn_market 710001)" "fund" "710001 → fund（7开头）"
assert_eq "$(identify_cn_market 810001)" "fund" "810001 → fund（8开头）"
assert_eq "$(identify_cn_market 960001)" "fund" "960001 → fund（9开头）"

describe "输入类型识别 — 全球市场"

# 复现 query_price.sh 的全局输入分类逻辑
identify_input() {
  local code="$1"
  if [[ "$code" =~ ^\.[A-Z]+$ ]]; then
    echo "us_index"
  elif [[ "$code" =~ ^[A-Za-z] ]]; then
    echo "us_stock"
  elif [[ "$code" =~ ^[0-9]{5}$ ]]; then
    echo "hk_stock"
  elif [[ "$code" =~ ^[0-9]{6}$ ]]; then
    echo "cn_stock"
  else
    echo "invalid"
  fi
}

# 港股（5 位数字）
assert_eq "$(identify_input 00700)" "hk_stock" "00700 → hk_stock（腾讯控股）"
assert_eq "$(identify_input 09988)" "hk_stock" "09988 → hk_stock（阿里巴巴）"
assert_eq "$(identify_input 03690)" "hk_stock" "03690 → hk_stock（美团）"
assert_eq "$(identify_input 01810)" "hk_stock" "01810 → hk_stock（小米）"

# 美股 ticker（英文开头）
assert_eq "$(identify_input AAPL)" "us_stock" "AAPL → us_stock（苹果）"
assert_eq "$(identify_input TSLA)" "us_stock" "TSLA → us_stock（特斯拉）"
assert_eq "$(identify_input BIDU)" "us_stock" "BIDU → us_stock（百度）"
assert_eq "$(identify_input NVDA)" "us_stock" "NVDA → us_stock（英伟达）"

# 美股指数（.开头）
assert_eq "$(identify_input .DJI)" "us_index" ".DJI → us_index（道琼斯）"
assert_eq "$(identify_input .IXIC)" "us_index" ".IXIC → us_index（纳斯达克）"
assert_eq "$(identify_input .SPX)" "us_index" ".SPX → us_index（标普500）"

# A 股（6 位数字）
assert_eq "$(identify_input 600519)" "cn_stock" "600519 → cn_stock"
assert_eq "$(identify_input 000001)" "cn_stock" "000001 → cn_stock"
assert_eq "$(identify_input 518880)" "cn_stock" "518880 → cn_stock"
