# stock-query 项目规范

## 仓库结构

这是一个发布到 ClawHub 的 openclaw skill，支持查询全球主要市场股票行情（A 股、港股、美股）、ETF、场外基金及主要指数，同时兼容 Claude Code 原生格式，使用单一 SKILL.md：

| 路径 | 格式 | 触发方式 |
|------|------|---------|
| `SKILL.md` + `skill.yaml` | OpenClaw | 自然语言关键词，`npx clawhub install` 安装 |
| `SKILL.md`（同一文件） | Claude Code 原生 | `/stock-query` slash command |

`SKILL.md` frontmatter 同时含有 OpenClaw 字段（`name`、`version`、`description`）和 Claude Code 字段（`user-invocable`、`allowed-tools`）。OpenClaw 规范未限制额外字段，ClawHub 只提取它关心的字段。

## description 写法规范

`description` 字段决定 Claude 是否主动识别用户意图调用 skill（不等待斜杠命令）：
- 必须包含 `TRIGGER when: <触发条件>` — 否则 Claude 会绕过 skill 自己实现
- 必须包含 `NOT for: <排除场景>` — 防止误触发

## 修改规范

**只有一个 SKILL.md，直接修改即可。** 修改后运行 `bash tests/install_local.sh` 同步到 skill 目录。

**新增脚本时须同步五处**：`tests/install_local.sh`（本地开发）、`install.sh`（用户安装）、CLAUDE.md 发布流程命令、`skill.yaml requires.bins`（新增依赖）、SKILL.md `前置依赖` 表格 + `静默执行原则`（声明脚本输出性质）；漏任一处都会导致功能异常或 ClawHub 扫描警告。

## 版本与发布

- **测试顺序**：`bash bump.sh patch|minor|major alpha` → `bash tests/install_local.sh` 同步 → `bash tests/datasource_check.sh && bash tests/check.sh`；bump alpha 必须在 install_local.sh 之前（否则同步的是旧版本号）
- **发布顺序**（以测试全过为前提）：**逐项核查 ClawHub 安全扫描项** → **完整更新 CHANGELOG.md** → `bash bump.sh release` → git commit + push → 发 ClawHub；禁止在 CHANGELOG 未完整时 commit
- **版本管理**：使用 `bump.sh` 统一管理（自动同步四处）；预发布格式 `X.Y.Z-alpha.N`（`bash bump.sh minor alpha` 开启，`bash bump.sh alpha` 递增，`bash bump.sh release` 发正式版）
- 注意：`SKILL.md` Step 0 正文含硬编码版本字符串（`stock-query vX.X.X`），`bump.sh` 已自动处理；手动 bump 时需用 `replace_all` 一并替换
- **ClawHub 发布**：只在 openclaw skill（`skill.yaml`、根目录 `SKILL.md`）有变化时执行；description/触发条件改动发 patch，功能改动发 minor/major；`claude/` 目录的改动不需要触发 ClawHub 发布
- **ClawHub 安全扫描**：扫描器检查以下类别：Purpose & Capability（功能与描述一致性）、Instruction Scope（操作边界明确性）、Credentials（环境变量声明完整性）、Persistence & Privilege（权限组合说明）。修改 skill.yaml/SKILL.md 后如触发扫描警告，参见下方"安全扫描修复规范"。

### ClawHub 发布流程

```bash
mkdir -p /tmp/stock-query/scripts
cp SKILL.md /tmp/stock-query/
cp skill.yaml /tmp/stock-query/
cp -r assets /tmp/stock-query/
cp scripts/sq.sh scripts/fmt.sh scripts/portfolio.sh /tmp/stock-query/scripts/
npx clawhub publish /tmp/stock-query --version X.X.X --slug stock-query
rm -rf /tmp/stock-query
```

- **`skill.yaml` 必须随 SKILL.md 一起发布**：其 `env:`/`permissions:` 声明是安全扫描器识别凭证与权限范围的机器可读来源，缺失会触发 Credentials/Instruction Scope 警告
- 发布目录结构需与项目一致：`scripts/sq.sh`、`scripts/portfolio.sh` 均在 `scripts/` 子目录下
- `assets/` 需要一并发布，install 时会将其安装到 skill 目录
- `scripts/portfolio.sh` **必须随 skill 发布**（历史兼容）；v2.2.0 起 Command 1 内置 grep/awk 直接操作 portfolio.csv，不再依赖此脚本

## 关键目录与文件

| 路径 | 用途 |
|------|------|
| `scripts/sq.sh` | 行情查询 CLI，**随 skill 发布**，`sq get`/`sq fund`/`sq hist`/`sq pfile` 四个子命令 |
| `scripts/fmt.sh` | 格式化输出工具，**随 skill 发布**，`sq.sh --format` 依赖此脚本；缺失时回退输出原始 JSON |
| `scripts/portfolio.sh` | **随 skill 发布**（历史兼容）；v2.2.0 起 Command 1 改为内联 bash，不再依赖此脚本 |
| `assets/portfolio.csv` | 自选股文件示例模板，随 skill 一起安装到 skill 目录 |

### portfolio_file 使用规范

- 用户实际文件路径：`{skill_install_dir}/portfolio.csv`（不存在时 skill 引导用户从 `assets/portfolio.csv` 复制创建，install.sh 不自动创建）
- **install.sh 行为应与 clawhub 安装保持一致**：只装 `SKILL.md` + `assets/`，不做用户文件初始化
- 格式：CSV，表头 `代码,名称,数量,自选价格`，`#` 开头为注释行
- 名称/数量/自选价格均可留空；数量为 0 表示纯自选（只查行情）
- `assets/portfolio.csv` 随 skill 一起发布，install.sh 和 clawhub 安装后均可在 skill 目录下找到

## 安全扫描修复规范（ClawHub OpenClaw Scanner）

- **Credentials / 未声明环境变量**：`skill.yaml` 需在 `env:` 块中显式声明脚本使用的所有环境变量，与 `config:` 分开维护；如无自定义环境变量则不需要 `env:` 块
- **Purpose & Capability**：`description` 必须涵盖 skill 的全部能力（含文件管理等非只读操作），不能只描述主功能
- **Instruction Scope**：SKILL.md 需有"权限与操作范围"章节，明确：① 每个权限的具体用途和限制，② 文件操作仅在用户显式指令下触发，③ 网络访问仅限声明的域名白名单
- **Persistence & Privilege**：`permissions:` 条目加内联注释（`# 用途: ...`）说明各权限的限制范围
- **Instruction Scope 误判**：扫描器看到脚本 `printf/echo` 就认为违反"静默执行原则"；解法：在 SKILL.md 该章节标题加"（Claude 对话输出约束）"并加注"脚本 stdout 为结构化 JSON，不影响此约束"

## 数据源

- **腾讯财经**（`qt.gtimg.cn`）— 首选，支持 A 股/港股/美股，GBK 编码，`~` 分隔字段
- **新浪财经**（`hq.sinajs.cn`）— A 股备用，GBK 编码，`,` 分隔字段，需 `Referer` header
- 两者响应均需 `| iconv -f GBK -t UTF-8` 转码
- **东方财富行情**（`push2.eastmoney.com`）— 港股/美股备用，UTF-8，JSON 响应，无需 iconv；港股 `secid=116.xxxxx`；美股先试 `secid=105.TICKER`（NASDAQ），null 时试 `106.TICKER`（NYSE）；`fltt=2` 参数直接返回浮点值，f43=最新价 f58=名称 f169=涨跌额 f170=涨跌幅%
- **腾讯历史K线**（`web.ifzq.gtimg.cn`）— A股/港股历史K线主源；URL 参数格式：`sym,period,start,end,count,adjust`（period=day/week/month，adjust=qfq/hfq/空，start/end 为 YYYY-MM-DD 或空）；响应 key：A股+qfq→`qfqday`，港股固定→`day`；港股不支持复权（adjust 强制空，fq 字段应改为 none）；股票名称以 `\uXXXX` JSON escape 格式返回，需 `_ujson` 解码
- **东方财富历史K线**（`push2his.eastmoney.com`）— 美股历史K线；直接 curl 返回空响应（HTTP 52，同 push2.eastmoney.com），L7.11 在开发环境会 SKIP；secid 格式：A股 `1./0.`，港股 `116.`，美股 `105.`(NASDAQ)→`106.`(NYSE)

腾讯 API 前缀：`sh`/`sz`(A股) · `hk`(港股5位) · `us`+ticker(美股) · `us.XXX`(美股指数)
腾讯字段索引（`~` 分隔）：[1]名称 [3]最新价 [4]昨收 [30]日期时间 [31]涨跌额 [32]涨跌幅% [33]最高 [34]最低
频率限制：≤100 代码/次，间隔 ≥100ms，过度调用封 IP

## 注意事项

- **git commit**：不可用 heredoc（`-m "$(cat <<'EOF'...)"`），会触发 1Password 填充失败；改用 `-m "多行字符串"` 形式
- **openclaw `--session-id`**：每次创建独立对话线程（无历史共享），但不产生 session store 条目（`openclaw sessions` 看不到）；agent memory 文件在所有 session 间共享
- **openclaw jq 提取**：多轮响应用 `jq -r '[.result.payloads[].text] | join("\n")'`，不要用 `payloads[0]`（会截断后续 payload）

## 测试注意事项

- **测试套件**：`tests/` 目录下有完整 L0-L7 测试套件，流程见 `tests/README.md`，用例见 `tests/cases.md`，结果记录到 `tests/results/YYYY-MM-DD.md`（gitignored）
- **Shell 自动层**：L0（`datasource_check.sh`）、L1-L7（`check.sh`，50 项）全部为 shell 自动断言，无需 agent
- **快速回归**：`bash tests/datasource_check.sh && bash tests/check.sh`（~80s，exit 0 即全通过）
- **测试结果记录**：每次跑完 `check.sh` 后必须将结果写入 `tests/results/YYYY-MM-DD.md`，包括 PASS/FAIL 汇总与本次修复说明
- **install_local.sh 覆盖范围**：同步到 `~/.openclaw/workspace/skills/stock-query/`；若 `~/.claude/skills/stock-query/` 存在也一并同步（含 `scripts/sq.sh`）
- **L6 前置**：备份并替换 portfolio.csv（路径：`~/.openclaw/workspace/skills/stock-query/portfolio.csv`）
- **portfolio.csv 路径**：固定在默认安装目录（openclaw 或 claude），不支持自定义环境变量；测试套件通过临时重命名文件模拟 NOT_FOUND（L6.7）
- **东方财富 push2 API**：`push2.eastmoney.com` 直接 curl 无额外 headers 返回空响应（HTTP 52），L0 DS-5/DS-6 失败时优先排查 headers 而非网络连通性；主力腾讯源正常则不影响功能
- **check.sh `--skip-network` SKIP 计数**：新增网络测试层时须同步更新 `SKIP=$((SKIP + ...))` 那行数字；当前各层项数：L2=13, L3=5, L4=5, L5=4, L7=11

## Skill 指令调优方法论

- **文字禁令效果有限**：`禁止做X` 类指令对持续性行为问题效果不稳定
- **有效方案**：改为伪代码分步逻辑（`Step A: ... Step B: ... Step D: 不得跳过`），明确执行顺序比措辞强调更有效——TC-5.4 数量=0 条目缺失问题经 4 次迭代，伪代码方案最终生效
- **emoji 规则修复**：agent 对港股/批量查询自行拼表格时会用错 emoji（🔴当跌色）。有效组合：Step 2 改伪代码 + 禁止列表中显式注明"港股跌幅用🟢"；单独一条禁令无效
- **版本分级**：指令调优 → patch；功能新增/流程变更 → minor/major
- **Command 编号**：Command 1 = Portfolio 文件管理（优先路由），Command 3 = 历史行情查询（历史/K线关键词触发），Command 2 = 行情查询（默认 fallback），无 Command 0
