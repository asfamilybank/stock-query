# stock-query 测试用例

评级说明见 `README.md`。

---

## §1 代码识别（L1+L2，Shell 自动）

L1/L2 由 `tests/check.sh` 自动执行，无需 agent：

```bash
bash tests/check.sh
```

### 覆盖范围

| check.sh 用例 | 内容 |
|---|---|
| L1.1 | sq get 无参数 → usage |
| L1.2 | sq fund 无参数 → usage |
| L1.3 | sq pfile → 合法路径或 NOT_FOUND |
| L1.4 | sq 无子命令 → usage |
| L2.1 | 沪市股票 601991 → A股/CNY/price非null |
| L2.2 | 深市股票 000002（非白名单）→ A股/price非null |
| L2.3 | 沪市指数 000300（白名单）→ A股/type=index |
| L2.4 | 深市指数 399006 → A股/type=index |
| L2.5 | 沪市 ETF 510300 → A股/type=etf |
| L2.6 | 港股 00700（5位）→ 港股/HKD/price非null |
| L2.7 | 港股 700（4位，自动补零）→ 港股/HKD/price非null |
| L2.8 | 美股 AAPL → 美股/USD/price非null |
| L2.9 | 美股指数 .IXIC → 美股/price非null |
| L2.10 | 场外基金 014978 → 基金/price非null |
| L2.11 | 无效代码 XYZNOTEXIST → error非null 或 price=null |
| L2.12 | 批量 AAPL/00700/601991 → 3项，顺序美股/港股/A股 |
| L2.13 | 深市非白名单 000568（probe）→ A股/price非null |

以下用例涉及模型行为（中文名映射、meta 命令），仍需 agent 执行。

---

### TC-1.10 中文名称映射

```bash
openclaw agent -m "查一下腾讯和苹果的股价" \
  --session-id "sq-tc-1.10-$(date +%s)" --json 2>/dev/null \
  | jq -r '[.result.payloads[].text] | join("\n")'
```

**PASS：**
- 无需用户提供代码，直接输出 `00700`（腾讯）和 `AAPL`（苹果）两行数据

**PARTIAL：**
- 识别出标的但询问确认代码，或只返回一个

**FAIL：**
- 无法识别中文名，或返回不相关标的

---

### TC-1.12 Meta 命令 — version

```bash
openclaw agent -m "/stock-query version" \
  --session-id "sq-tc-1.12-$(date +%s)" --json 2>/dev/null \
  | jq -r '[.result.payloads[].text] | join("\n")'
```

**PASS：**
- 输出 `stock-query v2.3.0`，不执行行情查询

**PARTIAL：**
- 输出版本号但格式不完全匹配（如 `version: 2.3.0`）

**FAIL：**
- 版本号错误，或触发了行情查询

---

### TC-1.13 Meta 命令 — help

```bash
openclaw agent -m "/stock-query help" \
  --session-id "sq-tc-1.13-$(date +%s)" --json 2>/dev/null \
  | jq -r '[.result.payloads[].text] | join("\n")'
```

**PASS：**
- 包含用法说明、支持的市场类型、至少 2 个示例，不触发行情查询

**PARTIAL：**
- 包含帮助内容，但缺少示例或市场列表

**FAIL：**
- 触发行情查询，或输出为空

---

## §2 行情格式（L3，Agent）

验证 Step 5：Markdown 表格、字段完整性、emoji 规则。

Agent 调用格式：
```bash
openclaw agent -m "<输入>" \
  --session-id "sq-<用例编号>-$(date +%s)" \
  --json 2>/dev/null | jq -r '[.result.payloads[].text] | join("\n")'
```

---

### TC-3.1 标准模式字段完整性

```bash
openclaw agent -m "/stock-query 601991" --session-id "sq-tc-3.1-$(date +%s)" --json 2>/dev/null \
  | jq -r '[.result.payloads[].text] | join("\n")'
```

**PASS：**
- Markdown 表格，含：代码、名称、市场、最新价、昨收、涨跌幅、最高、最低、币种、更新时间
- 所有字段有值
- 涨跌幅格式：`🔴 +X.XX%` / `🟢 -X.XX%` / `⚪ 0.00%`

**PARTIAL：**
- 核心字段（代码/名称/最新价/涨跌幅）完整，但昨收/最高/最低/更新时间有缺失

**FAIL：**
- 无 Markdown 表格，或最新价缺失

---

### TC-3.2 详细模式字段完整性

```bash
openclaw agent -m "/stock-query 601991 详细" --session-id "sq-tc-3.2-$(date +%s)" --json 2>/dev/null \
  | jq -r '[.result.payloads[].text] | join("\n")'
```

**PASS：**
- 比标准模式列更多，新增列含：今开、涨跌额、成交量（含"手"单位）、换手率

**PARTIAL：**
- 输出了扩展表格，但缺少成交量/换手率等辅助字段

**FAIL：**
- 未触发 detail_mode，仍输出标准表格

---

### TC-3.3 跨市场批量查询

```bash
openclaw agent -m "/stock-query AAPL 00700 601991 510300" --session-id "sq-tc-3.3-$(date +%s)" --json 2>/dev/null \
  | jq -r '[.result.payloads[].text] | join("\n")'
```

**PASS：**
- 一张表格输出 4 行，市场列分别为美股/港股/A股/A股，币种分别为 USD/HKD/CNY/CNY

**PARTIAL：**
- 4 行数据均有，但市场标签或币种部分缺失

**FAIL：**
- 输出少于 4 行，或有标的查询失败未提示

---

### TC-3.4 A股涨跌 emoji（红涨绿跌）

```bash
openclaw agent -m "/stock-query 000001 上证指数" --session-id "sq-tc-3.4-$(date +%s)" --json 2>/dev/null \
  | jq -r '[.result.payloads[].text] | join("\n")'
```

**PASS：**
- 涨 → 🔴，跌 → 🟢，平 → ⚪，规则正确

**PARTIAL：**
- emoji 颜色正确，但 `+/-` 符号缺失或格式有偏差

**FAIL：**
- 使用了美股的绿涨红跌规则（🟩/🟥）

---

### TC-3.5 美股涨跌 emoji（绿涨红跌）

```bash
openclaw agent -m "/stock-query TSLA" --session-id "sq-tc-3.5-$(date +%s)" --json 2>/dev/null \
  | jq -r '[.result.payloads[].text] | join("\n")'
```

**PASS：**
- 涨 → 🟩，跌 → 🟥，平 → ⚪，与 A 股规则相反

**PARTIAL：**
- emoji 颜色正确，但未使用方形 emoji（用了 🔴/🟢）

**FAIL：**
- 使用了 A 股规则（🔴/🟢）

---

### TC-3.6 美股指数批量

```bash
openclaw agent -m "/stock-query .DJI .IXIC .SPX" --session-id "sq-tc-3.6-$(date +%s)" --json 2>/dev/null \
  | jq -r '[.result.payloads[].text] | join("\n")'
```

**PASS：**
- 3 行，道琼斯/纳斯达克/标普500均有名称和数据

**PARTIAL：**
- 数据正确，但部分指数名称显示为代码

**FAIL：**
- 少于 3 行，或有失败未提示

---

### TC-3.7 港股详细模式

```bash
openclaw agent -m "/stock-query 09988 详情" --session-id "sq-tc-3.7-$(date +%s)" --json 2>/dev/null \
  | jq -r '[.result.payloads[].text] | join("\n")'
```

**PASS：**
- 触发 detail_mode，输出扩展表格，市场 `港股`，币种 `HKD`

**PARTIAL：**
- 数据正确，但"详情"未触发扩展列（仍为标准模式）

**FAIL：**
- 无输出，或识别为 A 股

---

### TC-3.8 无效 A 股代码

```bash
openclaw agent -m "/stock-query 999999" --session-id "sq-tc-3.8-$(date +%s)" --json 2>/dev/null \
  | jq -r '[.result.payloads[].text] | join("\n")'
```

**PASS：**
- 输出"未找到标的"或"请确认代码是否正确"，不输出空行情表格

**PARTIAL：**
- 有提示，但措辞模糊（如"暂时无法获取数据"），未引导用户确认代码

**FAIL：**
- 输出空表格并声称成功，或无任何提示

---

### TC-3.9 非交易时段提示

> ⚠️ 仅在非交易时段（收盘后、周末）执行；否则 SKIP。

```bash
openclaw agent -m "/stock-query 601991" --session-id "sq-tc-3.9-$(date +%s)" --json 2>/dev/null \
  | jq -r '[.result.payloads[].text] | join("\n")'
```

**PASS：**
- 表格下方含 `⏸ 非交易时段，显示上一交易日收盘数据`

**PARTIAL：**
- 有非交易时段说明，但措辞不完整（如只说"非交易时段"未说明数据来源）

**FAIL：**
- 无任何时段提示，用户无法判断数据是否实时

---

## §3 场外基金（L4，Agent）

验证 Step 4：估值/净值切换、QDII 标注。

---

### TC-4.1 场外基金盘中（估算净值）

> ⚠️ 仅在 A 股交易时段（工作日 09:30-15:00）执行；否则 SKIP。

```bash
openclaw agent -m "/stock-query 014978" --session-id "sq-tc-4.1-$(date +%s)" --json 2>/dev/null \
  | jq -r '[.result.payloads[].text] | join("\n")'
```

**PASS：**
- gztime 日期 = 今日，涨跌幅标注 `（估）`

**PARTIAL：**
- 使用了估值数据，但未标注 `（估）`

**FAIL：**
- 盘中仍使用昨日净值，或无数据

---

### TC-4.2 场外基金盘后（确认净值）

> ⚠️ 仅在 A 股收盘后或非交易日执行；否则 SKIP。

```bash
openclaw agent -m "/stock-query 014978" --session-id "sq-tc-4.2-$(date +%s)" --json 2>/dev/null \
  | jq -r '[.result.payloads[].text] | join("\n")'
```

**PASS：**
- 使用确认净值，标注 `（净值，非估值）`

**PARTIAL：**
- 使用了确认净值，但未标注；或数据日期正确但标注有误

**FAIL：**
- 使用了过期估值数据，未做新鲜度检查

---

### TC-4.3 QDII 基金

```bash
openclaw agent -m "/stock-query 015962" --session-id "sq-tc-4.3-$(date +%s)" --json 2>/dev/null \
  | jq -r '[.result.payloads[].text] | join("\n")'
```

> 若 `015962` 非 QDII，替换为其他已知 QDII 代码（名称含"海外/美国/纳斯达克/标普"）。

**PASS：**
- 输出包含 `QDII基金，净值公布有 T+2~T+7 延迟`

**PARTIAL：**
- 有延迟相关提示，但措辞不完整（如只提"延迟"未说明天数）

**FAIL：**
- 无任何 QDII 延迟提示

---

### TC-4.4 基金与股票批量混合

```bash
openclaw agent -m "/stock-query 014978 601991 AAPL" --session-id "sq-tc-4.4-$(date +%s)" --json 2>/dev/null \
  | jq -r '[.result.payloads[].text] | join("\n")'
```

**PASS：**
- 3 行，市场标签分别为基金/A股/美股，基金行含净值标注，其余行无

**PARTIAL：**
- 3 行数据均有，但市场标签统一（未区分基金与股票）

**FAIL：**
- 少于 3 行，或基金被当作股票处理

---

## §4 边界与错误处理（L3/L5，Agent）

> TC-4.3/4.4/4.13（000xxx 白名单/非白名单/probe 路由）已由 check.sh L2.3/L2.2/L2.13 覆盖，
> 此处仅列需要 agent 判断的用例。

---

### TC-5.1 Command 1 意图路由

```bash
openclaw agent -m "把 601991 加到自选股" --session-id "sq-tc-5.1-$(date +%s)" --json 2>/dev/null \
  | jq -r '[.result.payloads[].text] | join("\n")'
```

**PASS：**
- 路由到 Command 1，不返回行情表格，进入文件定位流程

**PARTIAL：**
- 路由正确，但在执行 Command 1 前先输出了 601991 的行情

**FAIL：**
- 路由到 Command 2，返回行情表格

---

### TC-5.2 沪深同号碰撞校验

```bash
openclaw agent -m "查一下 sh000001 和 sz000001" --session-id "sq-tc-5.2-$(date +%s)" --json 2>/dev/null \
  | jq -r '[.result.payloads[].text] | join("\n")'
```

**PASS：**
- 2 行，分别对应上证指数和平安银行，名称正确区分

**PARTIAL：**
- 返回 2 行数据，但名称有混淆或未明确区分

**FAIL：**
- 只返回 1 行，或两行返回相同标的

---

## §5 持仓计算（L5，Agent）

验证 Step 6：市值计算、浮盈亏、portfolio 文件读取。

---

### TC-6.1 单标的持仓计算（内联）

```bash
openclaw agent -m "我持有 601991 1000股，成本价 4.00，帮我算一下盈亏" --session-id "sq-tc-6.1-$(date +%s)" --json 2>/dev/null \
  | jq -r '[.result.payloads[].text] | join("\n")'
```

**PASS：**
- 行情表格 + 持仓市值表，含持仓/成本价/最新价/市值/浮盈亏/盈亏比
- 计算正确：市值 = 最新价 × 持仓数，浮盈 = (最新价 - 成本价) × 持仓数

**PARTIAL：**
- 输出了持仓市值表，但盈亏比（百分比）缺失，或市值与浮盈亏中只有一项

**FAIL：**
- 只输出行情表格，未计算持仓市值

---

### TC-6.2 跨市场持仓汇总

```bash
openclaw agent -m "帮我查持仓：601991 持有1000股成本4.00，AAPL 持有50股成本220" --session-id "sq-tc-6.2-$(date +%s)" --json 2>/dev/null \
  | jq -r '[.result.payloads[].text] | join("\n")'
```

**PASS：**
- 2 行持仓表格（A股 + 美股），计算正确，有跨市场币种提示

**PARTIAL：**
- 计算正确，但无跨市场币种区分提示

**FAIL：**
- 只计算了一个标的，或无持仓市值输出

---

### TC-6.3 成本价缺失

```bash
openclaw agent -m "我持有 510300 共 5000份，成本价不知道，查下现在多少钱" --session-id "sq-tc-6.3-$(date +%s)" --json 2>/dev/null \
  | jq -r '[.result.payloads[].text] | join("\n")'
```

**PASS：**
- 持仓市值表中浮盈亏列显示 `—`，市值列有值（最新价 × 持仓数）

**PARTIAL：**
- 市值正确，但浮盈亏列未显示 `—`（空白或省略）

**FAIL：**
- 未计算市值，或强行用 0 成本计算浮盈亏

---

### TC-6.4 从 portfolio 文件批量查询

> 前置：已有 portfolio.csv（含至少 2 个代码，持仓非 0 和为 0 各至少 1 个）。
> skill 通过 `sq pfile` 定位文件路径（openclaw 默认路径：`~/.openclaw/workspace/skills/stock-query/portfolio.csv`）。

```bash
openclaw agent -m "查我的持仓" --session-id "sq-tc-6.4-$(date +%s)" --json 2>/dev/null \
  | jq -r '[.result.payloads[].text] | join("\n")'
```

**PASS：**
- 正确读取 portfolio.csv，批量查询所有代码；持仓为 0 的只显示行情，非 0 且有成本价的显示浮盈亏

**PARTIAL：**
- 查询成功，但持仓为 0 的标的也计算了市值（显示 0），或浮盈亏格式不规范

**FAIL：**
- 未读取文件（凭空回复），或文件读取失败无提示

---

## §6 Command 1 CRUD（L6，Agent）

> ⚠️ 执行前准备测试文件（使用默认路径，`PORTFOLIO_FILE` 环境变量无法透传到 agent）：
> ```bash
> cp ~/.openclaw/workspace/skills/stock-query/portfolio.csv \
>    ~/.openclaw/workspace/skills/stock-query/portfolio.csv.bak 2>/dev/null || true
> cp ~/.openclaw/workspace/skills/stock-query/examples/portfolio.csv \
>    ~/.openclaw/workspace/skills/stock-query/portfolio.csv
> ```
> 测试完成后恢复：
> ```bash
> mv ~/.openclaw/workspace/skills/stock-query/portfolio.csv.bak \
>    ~/.openclaw/workspace/skills/stock-query/portfolio.csv 2>/dev/null || true
> ```
> L6 用例须**按顺序执行**（TC-7.3 依赖 TC-7.2 的前置状态）。

---

### TC-7.1 查看自选股

```bash
openclaw agent -m "显示我的自选股" --session-id "sq-tc-7.1-$(date +%s)" --json 2>/dev/null \
  | jq -r '[.result.payloads[].text] | join("\n")'
```

**PASS：**
- 读取默认路径的 portfolio.csv（通过 `sq pfile` 定位），输出文件内容（含代码/名称/持仓/成本价），注释行和表头行不作为数据显示

**PARTIAL：**
- 读取文件成功，但以实时行情表格形式展示（而非原始文件内容）；或含注释/表头行

**FAIL：**
- 未读取文件（凭空回复），或提示文件不存在但文件实际存在

---

### TC-7.2 新增标的

> 使用 `科大讯飞`（002230）——不在 examples/portfolio.csv 中，确保测试"新增"而非"重复"分支。

```bash
openclaw agent -m "把科大讯飞加到自选股，持有500股，成本30.00" --session-id "sq-tc-7.2-$(date +%s)" --json 2>/dev/null \
  | jq -r '[.result.payloads[].text] | join("\n")'
```

**PASS：**
- 调用 `sq get 002230` 确认名称，执行 bash append 命令，输出 `✅ 已添加` 确认
- 验证：`grep 002230 ~/.openclaw/workspace/skills/stock-query/portfolio.csv` 有输出

**PARTIAL：**
- 正确追加到文件，但确认信息不含完整的代码/名称/持仓/成本价

**FAIL：**
- 未执行 bash 命令（声称已添加但文件未变），或追加内容格式错误

---

### TC-7.3 新增重复代码

> 前置：TC-7.2 已执行，`002230` 已在文件中。

```bash
openclaw agent -m "把002230加到自选股" --session-id "sq-tc-7.3-$(date +%s)" --json 2>/dev/null \
  | jq -r '[.result.payloads[].text] | join("\n")'
```

**PASS：**
- 检测到重复，提示"已在自选股中"，询问是否修改，文件中 `002230` 仍只有一行

**PARTIAL：**
- 有重复提示，但未给出下一步引导（是否修改）

**FAIL：**
- 重复追加（文件中出现两行 `002230`），或无任何提示

---

### TC-7.4 修改持仓

> 前置：TC-7.2 已执行，`002230` 已在文件中。

```bash
openclaw agent -m "把002230的持仓改成2000股，成本价35.00" --session-id "sq-tc-7.4-$(date +%s)" --json 2>/dev/null \
  | jq -r '[.result.payloads[].text] | join("\n")'
```

**PASS：**
- 执行 awk 替换，输出修改前后 diff，验证文件已更新
- 验证：`grep 002230 ~/.openclaw/workspace/skills/stock-query/portfolio.csv` 显示新值

**PARTIAL：**
- 文件修改正确，但 diff 展示不完整（只显示新值，未显示旧值）

**FAIL：**
- 未执行 bash 命令，或文件未变更，或创建了错误的文件类型（如 .md）

---

### TC-7.5 删除标的

> 前置：TC-7.2 已执行，`002230` 已在文件中。

```bash
openclaw agent -m "把002230从自选股删掉" --session-id "sq-tc-7.5-$(date +%s)" --json 2>/dev/null \
  | jq -r '[.result.payloads[].text] | join("\n")'
```

**PASS：**
- 执行 grep -v 删除，输出 `✅ 已删除` 及被删行内容
- 验证：`grep 002230 ~/.openclaw/workspace/skills/stock-query/portfolio.csv` 无输出

**PARTIAL：**
- 文件删除正确，但确认信息缺失或不完整

**FAIL：**
- 文件未变更，或删除了错误行

---

### TC-7.6 删除不存在的代码

```bash
openclaw agent -m "把999999从自选股删掉" --session-id "sq-tc-7.6-$(date +%s)" --json 2>/dev/null \
  | jq -r '[.result.payloads[].text] | join("\n")'
```

**PASS：**
- 提示"未找到该代码"，文件未被修改

**PARTIAL：**
- 有提示，但措辞未明确说明代码不存在（如"操作失败"）

**FAIL：**
- 无提示，或文件被意外修改

---

### TC-7.7 文件不存在引导

> 前置：临时移走默认路径下的 portfolio.csv：
> ```bash
> mv ~/.openclaw/workspace/skills/stock-query/portfolio.csv \
>    ~/.openclaw/workspace/skills/stock-query/portfolio.csv.tmp
> ```
> 测试完成后恢复：
> ```bash
> mv ~/.openclaw/workspace/skills/stock-query/portfolio.csv.tmp \
>    ~/.openclaw/workspace/skills/stock-query/portfolio.csv
> ```

```bash
openclaw agent -m "查我的自选股" --session-id "sq-tc-7.7-$(date +%s)" --json 2>/dev/null \
  | jq -r '[.result.payloads[].text] | join("\n")'
```

**PASS：**
- `sq pfile` 返回 NOT_FOUND，输出引导信息含创建命令（cp examples/...），不报错崩溃

**PARTIAL：**
- 有文件不存在提示，但引导信息不完整（未提供具体命令）

**FAIL：**
- 崩溃报错，或凭空返回空列表

---

## 附录：通用检查项

每条 Agent 用例评级前额外确认：

- 响应语言与输入语言一致（中文问 → 中文答）
- 价格数值合理（非 0、非负，数量级符合该市场）
- 无乱码（iconv 正常工作）
- 无原始 API 响应泄漏到输出（如 `v_sh601991=...` 原文）
