# cn-stock-query

实时查询中国 A 股股票、ETF 及场外基金价格，红涨绿跌一目了然。

## 安装

**通过 ClawHub（OpenClaw 格式，自然语言触发）：**

```bash
npx clawhub install cn-stock-query
```

或手动克隆：

```bash
cd ~/.openclaw/workspace/skills/
git clone https://github.com/asfamilybank/cn-stock-query.git
```

**通过 Claude Code（原生 slash command，`/cn-stock-query` 直接调用）：**

```bash
# 复制到项目级（仅当前项目可用）
mkdir -p .claude/skills/cn-stock-query
curl -o .claude/skills/cn-stock-query/SKILL.md \
  https://raw.githubusercontent.com/asfamilybank/cn-stock-query/main/claude/SKILL.md

# 或复制到用户级（所有项目可用）
mkdir -p ~/.claude/skills/cn-stock-query
curl -o ~/.claude/skills/cn-stock-query/SKILL.md \
  https://raw.githubusercontent.com/asfamilybank/cn-stock-query/main/claude/SKILL.md
```

## 功能概览

- **股票/ETF 实时行情** — 沪深两市全覆盖，支持批量查询
- **场外基金估值/净值** — 盘中实时估值 + 确认净值双模式
- **智能代码识别** — 自动判断市场（沪/深）和类型（股票/ETF/基金）
- **涨跌可视化** — 🔴 上涨 🟢 下跌 ⚪ 平盘，遵循 A 股红涨绿跌惯例
- **持仓市值计算** — 传入持仓和成本，自动算浮盈/亏
- **QDII 基金标注** — 自动识别 QDII 基金并标注净值延迟

## 使用方式

**OpenClaw 格式**（自然语言触发）：

```
查一下 601991 和 518880 的最新价
```

```
014978 现在净值多少
```

```
帮我查这些持仓的市值：601991 500股成本3.725，518880 200股成本10.925
```

也可以用名称查询：

```
查一下黄金ETF和卫星ETF的行情
```

**Claude Code 原生格式**（slash command）：

```
/cn-stock-query 601991 518880
/cn-stock-query 014978
/cn-stock-query 黄金ETF 卫星ETF
```

## 输出示例

```
| 代码   | 名称        | 类型  | 最新价 | 涨跌幅          | 更新时间           |
|--------|------------|-------|--------|----------------|-------------------|
| 601991 | 大唐发电    | stock | 4.310  | 🔴 +1.41%      | 2026-03-18 15:00  |
| 518880 | 黄金ETF华安 | etf   | 10.606 | 🟢 -0.29%      | 2026-03-18 15:00  |
| 014978 | 华安纳指C   | fund  | 6.8897 | 🟢 -1.43%（估） | 2026-03-18 15:00  |
```

## 支持的标的

| 类型     | 代码规则           | 示例              |
|---------|-------------------|-------------------|
| 沪市股票 | 6 开头 6 位        | 601991 大唐发电    |
| 深市股票 | 0 或 3 开头 6 位    | 000001 平安银行    |
| 沪市 ETF | 5 开头 6 位        | 518880 黄金ETF    |
| 深市 ETF | 1 开头 6 位        | 159915 创业板ETF   |
| 场外基金 | 其他 6 位数字       | 014978 华安纳指C   |

## 数据源

| 数据源    | 用途           | 是否需要 Key |
|----------|---------------|-------------|
| 新浪财经  | 股票/ETF 实时行情 | 否          |
| 天天基金  | 场外基金估值/净值  | 否          |
| 东方财富  | 净值备用接口      | 否          |

## 权限说明

| 权限      | 用途                                          |
|----------|-----------------------------------------------|
| network  | 调用新浪财经、天天基金、东方财富的公开 HTTP 接口    |
| shell    | 执行 curl 请求和 iconv 编码转换                  |

本 skill 仅对上述三个域名发起只读 GET 请求，不写入任何文件，不发送任何用户数据。

## 已知限制

- 不支持美股、港股、加密货币、期货
- 新浪财经接口为非官方 API，可能随时变动
- QDII 基金净值有 T+2 至 T+7 的系统性延迟
- 场外基金盘中仅提供估算净值，非最终确认净值

## 故障排查

| 问题             | 解决方案                                   |
|-----------------|--------------------------------------------|
| 中文名称乱码     | 确认系统已安装 iconv（macOS/Linux 自带）      |
| 某只股票查不到    | 检查代码是否为 6 位，确认市场前缀是否正确       |
| 基金估值显示过期  | QDII 基金属正常延迟；非 QDII 请检查是否为交易日 |
| 接口超时         | 运行 scripts/monitor.sh 检测接口可用性        |

## 附带脚本

- `scripts/query_price.sh` — 命令行批量查询工具
- `scripts/monitor.sh` — 接口可用性监控（建议每日收盘后运行）

## License

MIT
