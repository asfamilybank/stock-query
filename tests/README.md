# stock-query 测试说明

测试目的：在发布前验证当前开发内容，**测试通过后再执行 clawhub publish**。

---

## 测试分层

| 层级 | 内容 | 执行方式 | 耗时 |
|------|------|---------|------|
| L0 数据源存活 | 5 个上游 API 可达且可解析 | Shell 自动 | <10s |
| L1 代码识别 | Step 1-2 市场判断、格式解析 | CLI 半自动 | ~5min |
| L2 行情查询 | Step 3-5 字段、格式、emoji | CLI 半自动 | ~5min |
| L3 场外基金 | Step 4 估值/净值切换、QDII | CLI 半自动 | ~3min |
| L4 边界与错误 | fallback、歧义、无效代码 | CLI 半自动 | ~5min |
| L5 持仓计算 | Step 6 市值、浮盈亏 | CLI 半自动 | ~5min |
| L6 Command 3 | portfolio 增删改查 | CLI 半自动 | ~8min |

**快速回归**（发版前必跑）：L0 全部 + L1 全部 + L2（TC-2.1、TC-2.3、TC-2.5）+ L4 全部

**完整回归**：所有层级

---

## 评级标准

每条用例输出一个评级，**以最低维度为准**。

### 三档评级定义

| 评级 | 含义 |
|------|------|
| **PASS** | 所有通过条件满足，包括核心行为和格式要求 |
| **PARTIAL** | 核心功能正确（用户能获得有效信息），但有格式偏差、字段缺失或措辞问题 |
| **FAIL** | 核心功能错误、缺失，或输出对用户造成误导 |
| **SKIP** | 用例前置条件不满足（如时段限制），本次不执行 |

### 各维度判定规则

| 维度 | PASS | PARTIAL | FAIL |
|------|------|---------|------|
| **意图路由** | 正确路由到对应 Command | — | 路由错误（如行情查询路由到 Command 3） |
| **数据正确性** | 核心字段（代码/名称/价格/涨跌幅）全部有值且合理 | 辅助字段（换手率/PE/52W）部分缺失 | 核心字段缺失、为 0、或与标的明显不符 |
| **格式合规** | 完全符合 Step 5 规范（Markdown 表格、emoji 规则、标注） | 有轻微偏差（列顺序、小数位、单位写法） | 无表格、emoji 规则用反、关键标注缺失 |
| **错误处理** | 准确提示原因，引导用户下一步 | 提示存在但过于模糊或缺少引导 | 无提示、报原始错误、或声称成功实际失败 |
| **Command 3** | 通过 Bash 实际执行命令并确认结果 | 结果正确但确认信息不完整 | 未执行命令、文件未变更、或操作错误 |

### PARTIAL 的处理原则

- PARTIAL 不阻塞发布，但须在发布说明中记录，并在下个版本跟进
- 同一维度出现 2 个以上 PARTIAL 时，视为潜在系统性问题，需评估是否阻塞发布
- FAIL 必须修复后重新测试，不允许带 FAIL 发布

---

## 测试工具：openclaw CLI

### Session 隔离机制

`openclaw agent --session-id <唯一值>` 每次创建独立的对话线程（无历史消息共享）。**不需要新建 agent**——每个 session-id 对应一个独立的 message thread，足以防止用例间的对话污染。

注意：agent memory 文件（长期记忆）在所有 session 间共享，但 stock-query 测试为无状态用例，不依赖跨 session 的 memory，因此不受影响。

每个用例的 session-id 加时间戳后缀，防止多次测试运行之间碰撞：

```
sq-tc-<用例编号>-<timestamp>
```

### 命令格式

```bash
# 单条测试（提取回复文本）
openclaw agent -m "<输入内容>" \
  --session-id "sq-tc-<用例编号>-$(date +%s)" \
  --json 2>/dev/null \
  | jq -r '[.result.payloads[].text] | join("\n")'
```

不加 `jq` 则输出完整 JSON，含 token 用量、sessionId 等 meta 信息。

### 示例

```bash
# TC-1.1: 沪市6位数字
openclaw agent -m "/stock-query 601991" \
  --session-id "sq-tc-1.1-$(date +%s)" --json 2>/dev/null \
  | jq -r '[.result.payloads[].text] | join("\n")'

# TC-2.3: 跨市场批量
openclaw agent -m "/stock-query AAPL 00700 601991 510300" \
  --session-id "sq-tc-2.3-$(date +%s)" --json 2>/dev/null \
  | jq -r '[.result.payloads[].text] | join("\n")'
```

---

## 发布前完整流程

```
1. bash tests/datasource_check.sh          # L0 数据源存活检测
2. bash tests/install_local.sh             # 同步当前开发内容到本地 openclaw
3. 按 cases.md 逐条执行                    # L1-L6，用独立 session-id
4. 整理测试报告，所有用例达到 PASS/PARTIAL  # FAIL 须修复后重跑
5. 执行 clawhub publish                    # 见 CLAUDE.md「ClawHub 发布流程」
```

### L6 前置准备

L6 会写入文件，执行前隔离测试文件：

```bash
export PORTFOLIO_FILE=/tmp/sq_test_portfolio.csv
cp ~/.openclaw/workspace/skills/stock-query/examples/portfolio.csv /tmp/sq_test_portfolio.csv
```

---

## 注意事项

- **L0-L5 为只读**，不修改任何文件
- 行情数据实时变化，通过条件只校验**字段存在性和格式**，不校验具体数值
- 非交易时段运行时，部分用例的"更新时间"为上一交易日，属正常现象（不降级为 PARTIAL）
- 数据源偶发超时：单次失败可重试，连续 3 次失败才标记 FAIL
- L3 盘中/盘后用例二选一执行，另一条标记 SKIP

---

## 文件结构

```
tests/
├── README.md              本文件：测试流程与评级标准
├── cases.md               所有测试用例（L1-L6，含 PASS/PARTIAL/FAIL 条件）
├── datasource_check.sh    L0 数据源检测（Shell 自动运行）
└── install_local.sh       发布前同步当前开发内容到本地 openclaw
```
