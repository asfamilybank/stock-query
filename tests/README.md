# stock-query 测试说明

测试目的：在发布前验证当前开发内容，**测试通过后再执行 clawhub publish**。

---

## 测试分层

| 层级 | 内容 | 执行方式 | 耗时 |
|------|------|---------|------|
| L0 数据源存活 | 5 个上游 API 可达且可解析 | Shell 自动 | <10s |
| L1 sq CLI | sq get/fund/pfile 子命令完整性 | Shell 自动 | <5s |
| L2 市场识别 | 代码分类、字段完整性 JSON 断言 | Shell 自动 | <60s |
| L3 行情格式 | Step 5 Markdown 表格、emoji 规则、时段提示 | Agent 半自动 | ~5min |
| L4 场外基金 | Step 4 估值/净值切换、QDII | Agent 半自动 | ~3min |
| L5 持仓计算 | Step 6 市值、浮盈亏、portfolio 文件读取 | Agent 半自动 | ~5min |
| L6 Command 1 | portfolio 增删改查 | Agent 半自动 | ~8min |

**快速回归**（发版前必跑）：

```bash
bash tests/datasource_check.sh   # L0，<10s
bash tests/check.sh              # L1+L2，<70s
```

之后人工跑 L3（TC-3.1/TC-3.3）+ L5（TC-5.4），约 10min。

**完整回归**：所有层级。

---

## 评级标准

每条 Agent 用例输出一个评级，**以最低维度为准**。

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
| **意图路由** | 正确路由到对应 Command | — | 路由错误（如行情查询路由到 Command 1） |
| **数据正确性** | 核心字段（代码/名称/价格/涨跌幅）全部有值且合理 | 辅助字段（换手率/PE/52W）部分缺失 | 核心字段缺失、为 0、或与标的明显不符 |
| **格式合规** | 完全符合 Step 5 规范（Markdown 表格、emoji 规则、标注） | 有轻微偏差（列顺序、小数位、单位写法） | 无表格、emoji 规则用反、关键标注缺失 |
| **错误处理** | 准确提示原因，引导用户下一步 | 提示存在但过于模糊或缺少引导 | 无提示、报原始错误、或声称成功实际失败 |
| **Command 1** | 通过 Bash 实际执行命令并确认结果 | 结果正确但确认信息不完整 | 未执行命令、文件未变更、或操作错误 |

### PARTIAL 的处理原则

- PARTIAL 不阻塞发布，但须在发布说明中记录，并在下个版本跟进
- 同一维度出现 2 个以上 PARTIAL 时，视为潜在系统性问题，需评估是否阻塞发布
- FAIL 必须修复后重新测试，不允许带 FAIL 发布

---

## Shell 自动测试：check.sh

`tests/check.sh` 覆盖 L1 + L2，输出 PASS/FAIL/SKIP 汇总，exit 0 表示全部通过。

```bash
bash tests/check.sh              # 运行 L1+L2（需要网络）
bash tests/check.sh --skip-network  # 仅运行 L1
```

L1/L2 用例详见 `cases.md` §1。

---

## Agent 测试工具：openclaw CLI

### Session 隔离机制

`openclaw agent --session-id <唯一值>` 每次创建独立的对话线程（无历史消息共享）。

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

### 示例

```bash
# TC-3.1: 行情格式 + emoji
openclaw agent -m "/stock-query 601991" \
  --session-id "sq-tc-3.1-$(date +%s)" --json 2>/dev/null \
  | jq -r '[.result.payloads[].text] | join("\n")'

# TC-3.3: 跨市场批量
openclaw agent -m "/stock-query AAPL 00700 601991 510300" \
  --session-id "sq-tc-3.3-$(date +%s)" --json 2>/dev/null \
  | jq -r '[.result.payloads[].text] | join("\n")'
```

---

## 发布前完整流程

```
1. bash tests/datasource_check.sh          # L0 数据源存活检测
2. bash tests/install_local.sh             # 同步当前开发内容到本地 openclaw
3. bash tests/check.sh                     # L1+L2 自动断言
4. 按 cases.md §2-§6 逐条执行 Agent 测试   # L3-L6，用独立 session-id
5. 整理测试报告，所有用例达到 PASS/PARTIAL  # FAIL 须修复后重跑
6. 执行 clawhub publish                    # 见 CLAUDE.md「ClawHub 发布流程」
```

### L6 前置准备

L6 会写入文件，执行前隔离测试文件：

```bash
cp ~/.openclaw/workspace/skills/stock-query/portfolio.csv \
   ~/.openclaw/workspace/skills/stock-query/portfolio.csv.bak 2>/dev/null || true
cp ~/.openclaw/workspace/skills/stock-query/examples/portfolio.csv \
   ~/.openclaw/workspace/skills/stock-query/portfolio.csv
```

---

## 注意事项

- **L0-L5 为只读**，不修改任何文件
- 行情数据实时变化，check.sh（L2）只校验**字段存在性和分类**，不校验具体数值
- 非交易时段运行时，部分用例的"更新时间"为上一交易日，属正常现象（不降级为 PARTIAL）
- 数据源偶发超时：单次失败可重试，连续 3 次失败才标记 FAIL
- L4 盘中/盘后用例二选一执行，另一条标记 SKIP

---

## 文件结构

```
tests/
├── README.md              本文件：测试流程与评级标准
├── cases.md               所有测试用例（L1-L6，含 PASS/PARTIAL/FAIL 条件）
├── check.sh               L1+L2 自动断言（sq CLI + 市场识别）
├── datasource_check.sh    L0 数据源检测
├── install_local.sh       发布前同步当前开发内容到本地 openclaw
└── results/               测试结果记录（gitignored）
    └── YYYY-MM-DD.md
```
