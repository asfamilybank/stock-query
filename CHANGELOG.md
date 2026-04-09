# Changelog

## [2.6.0] - 2026-04-09

### Added
- `sq hist --detail`：新增 量MA5 / 量MA10 列（成交量5日/10日均线，A股/港股显示万手，美股显示原始数值）
- `sq get --detail`：同步新增 量MA5 / 量MA10 列，通过历史K线数据计算注入
- `--format csv`：get / hist 均新增 CSV 输出格式（`--format csv`）
- `--detail`：拆分为独立 boolean 参数，与 `--format` 正交（可单独使用，默认 table）
- 美股历史K线改用 Yahoo Finance（`query1.finance.yahoo.com`），替换无法访问的东方财富 `push2his` 接口

### Changed
- hist：多取 `lmt+61` 条额外K线，确保全部显示行的涨跌幅与 MA5/MA10 均非空
- `_enrich_detail_json`：`fetch_closes` 改为 `fetch_klines`，同时返回收盘价与成交量用于计算量MA
- `sq.sh` map 辅助函数：`eval` 替换为 `printf -v` + `${!var}` 间接展开（消除命令注入风险）
- 移除已无调用的 `em_hist_fetch` 函数
- 域名白名单：`push2his.eastmoney.com` 替换为 `query1.finance.yahoo.com`（skill.yaml / SKILL.md / 注释同步更新）
- SKILL.md frontmatter：新增 `license`、`compatibility`、`metadata`（含 version/author/repo）字段
- `bump.sh`：更新为读写 `metadata.version`（带缩进和引号）

### Fixed
- `tests/check.sh` L5.4：`batch_out` 为空时改为 SKIP（openclaw 间歇性返回空 payload），与 L5.1-L5.3 行为一致

## [2.5.1] - 2026-04-07

### Fixed
- SKILL.md description 从 706 字符精简至 123 字符，确保 TRIGGER when / NOT for 不被 Claude Code 250 字符截断限制丢弃

### Changed
- README 安装方式改为 Skills + ClawHub，移除 install.sh curl 方式
- README 使用方式合并，不再区分 OpenClaw / Claude Code
- README 权限说明补充 python3、grep/awk、portfolio.csv 路径
- README 已知限制修正白名单描述，补充港股历史K线不支持复权，移除已解决条目

## [2.5.0] - 2026-04-07

### Added
- **skills.sh 发布支持**：`npx skills add asfamilybank/stock-query` 一键安装，支持 40+ agent
- `sq.sh pfile` 新增 `~/.config/stock-query/portfolio.csv` 为主路径（XDG 标准，独立于 skill 安装目录，任何平台更新均不会删除），旧路径保留为 fallback

### Fixed
- 东方财富备用源（DS-5 港股、DS-6 美股）：`em_stock_fetch()` 补充 `Referer` header，修复直连返回空响应问题；L0 由 6/8 → 8/8 PASS

### Removed
- 移除 `scripts/portfolio.sh`（v2.2.0 起 Command 1 已改为内联 bash，此脚本仅历史兼容保留，现正式清理）
- `install.sh` 移除 portfolio.sh 下载与安装步骤

## [2.4.1] - 2026-04-03

### Changed
- 全面替换"持仓"术语为"自选"体系，降低隐私泄漏风险：
  - portfolio.csv 列名 `持仓` → `数量`，`成本价` → `自选价格`
  - "持仓市值" → "自选市值"，"持仓合计" → "自选合计"，"持仓=0" → "数量=0"
  - SKILL.md、skill.yaml description、README.md、clawhub.json 同步更新
  - 测试文件（check.sh、cases.md）及 assets/portfolio.csv 注释/表头同步更新

## [2.4.0] - 2026-04-03

### Added
- 历史K线表格新增 MA5/MA10/MA20/MA60 均线列
- 新增 `bump.sh` 版本管理工具，支持 semver 预发布全流程（alpha 递增、release、直接设定）
- `install.sh` / `tests/install_local.sh` 新增 `fmt.sh` 安装与同步

### Changed
- SKILL.md Step 2 改为伪代码（2A/2B），强化 emoji 禁令与港股涨跌色规则
- `skill.yaml` description 补充历史K线与均线说明，`requires.bins` 新增 `python3`
- SKILL.md 静默执行原则补充 `fmt.sh` 输出性质说明，前置依赖表格新增 `fmt.sh`

### Removed
- 移除 `scripts/monitor.sh`、`scripts/query_price.sh`（后者曾触发 ClawHub 安全扫描误报）

## [2.3.8] - 2026-04-02

### Fixed
- 从 ClawHub 发布包中移除 `scripts/query_price.sh`（含人类可读 INFO/WARN/ERROR 输出，触发安全扫描误报）

## [2.3.7] - 2026-04-02

### Fixed
- 删除 `sq.sh` 中永不触发的 PATH_REJECTED 死代码（路径已硬编码，运行时校验无意义）
- 移除 SKILL.md/`skill.yaml` 中凭证路径自动拒绝的声明，与代码实际行为保持一致
- 修正静默执行章节：stdout 描述由"结构化数据"改为"JSON 数组或 NOT_FOUND 令牌"

## [2.3.6] - 2026-04-02

### Changed
- 移除 `PORTFOLIO_FILE` 环境变量支持，`sq.sh`/`portfolio.sh` 改为直接遍历两个默认安装路径
- `skill.yaml` 删除 `env:` 块和 `config.portfolio_file`，消除 ClawHub Credentials 警告
- SKILL.md `description` 补全 Purpose & Capability（文件管理能力、权限范围、网络域名白名单）
- `tests/check.sh` L6.7 改用临时 `mv` 代替 `PORTFOLIO_FILE` 模拟 NOT_FOUND

## [2.3.5] - 2026-04-02

### Changed
- `examples/` 目录重命名为 `assets/`，发布包和安装路径同步更新

## [2.3.4] - 2026-04-02

### Fixed
- 修复 ClawHub 安全扫描警告：SKILL.md 静默执行原则补充说明（仅约束 Claude 对话输出，脚本 stdout 为结构化 JSON）
- SKILL.md Command 1 增加 PATH_REJECTED 处理分支
- `skill.yaml` description 补充路径校验行为说明

## [2.3.1] - 2026-04-01

### Fixed
- A股/港股成交量展示由原始手数换算为万手，与市场惯例一致

## [2.3.0] - 2026-04-01

### Added
- 新增 `scripts/sq.sh`：独立行情查询 CLI，支持 `get`/`fund`/`hist`/`pfile` 四个子命令，输出结构化 JSON
- 新增 `tests/check.sh`：L1–L6 全自动 shell 断言（38 项），覆盖市场识别、字段完整性、emoji 规则、portfolio CRUD

### Changed
- Portfolio 管理从 Command 3 重命名为 **Command 1**（最高优先路由）
- 合并 `claude/SKILL.md` 与根目录 `SKILL.md` 为单一文件，消除双维护负担
- 重写 `tests/README.md` 和 `tests/cases.md`，统一测试分层与用例编号

## [2.2.1] - 2026-03-31

### Added
- 新增 `tests/`：L0–L6 完整测试套件（`datasource_check.sh`、`install_local.sh`、`cases.md`）

### Fixed
- 强化静默执行原则：明确禁止输出市场/类型判断、数据源切换等过程信息
- 修复批量查询 emoji 混淆：每行按自身市场独立判断，禁止跨行影响
- 修复 Step 6b 竖向键值对：任何情况下强制使用横向宽表格
- 修复 Step 6a 持仓=0 条目缺失：伪代码分步逻辑（Step A/B/C/D），Step D 不得跳过
- 修复 Step 6 美股盈亏 emoji：P&L 列遵循市场规则（🟩/🟥）

## [2.2.0] - 2026-03-25

### Added
- 新增东方财富 `push2.eastmoney.com` 为港股/美股备用数据源

### Changed
- 港股代码自动补全前置零前置（700→00700，3/4 位均适用）
- 000xxx 指数白名单替代二次 API 调用，消除延迟和误判风险
- 场外基金新鲜度判断简化：`gztime_date == today` 判断当日估值
- Command 1 去除 `portfolio.sh` 路径依赖，改为内联 bash（grep/awk）直接操作 portfolio.csv

## [2.1.2] - 2026-03-25

### Fixed
- `skill.yaml` 声明 `PORTFOLIO_FILE` 为正式 env 变量，解决 ClawHub "未声明环境变量"告警
- `skill.yaml` description 补充文件管理能力、文件访问范围、网络访问范围
- `skill.yaml` permissions 添加内联注释说明各权限用途与限制
- SKILL.md 新增"权限与操作范围"章节，显式声明 network/shell 限制、文件访问约束、自动触发范围

## [2.1.1] - 2026-03-25

### Fixed
- 同步两个 SKILL.md 的触发描述为 `TRIGGER when` 措辞

## [2.1.0] - 2026-03-25

### Added
- 新增 `scripts/portfolio.sh`：portfolio.csv 增删改查 shell 脚本
- 重构为三命令架构（Meta / 行情查询 / Portfolio 管理），新增 `detail_mode`、基金数据新鲜度检查
- 输出表格新增昨收列

## [2.0.2] - 2026-03-24

### Added
- 输出表格新增最高价/最低价字段

## [2.0.1] - 2026-03-24

### Fixed
- 修正 ClawHub 发布时 display name 误用临时目录名的问题

## [2.0.0] - 2026-03-24

### Added
- 港股（腾讯财经 `qt.gtimg.cn`）、美股（腾讯财经）支持
- 美股三大指数（.DJI / .IXIC / .SPX）支持
- 项目重命名为 `stock-query`，slug/包名全部更新
- `install.sh` 一键安装脚本，支持版本检测与更新提示

### Changed
- 数据源首选切换为腾讯财经（原新浪财经降为 A股备用）
- GBK→UTF-8 编码转换统一处理港股/美股响应

## [1.0.4] - 2026-03-24

### Added
- `claude/SKILL.md`：新增 Claude Code 原生 skill 文件，支持 `/cn-stock-query` slash command 直接调用，无需自然语言触发
- README 补充 Claude Code 安装方式（用户级/项目级）及 slash command 使用示例

## [1.0.3] - 2026-03-19

### Changed
- SKILL.md：增加「安全与隐私说明」小节，说明基金估值接口（fundgz.1234567.com.cn）为 HTTP 无 TLS 的用途与风险，以及 portfolio_file 配置项不自动读取、勿指向敏感文件的提示
- skill.yaml：在 config.portfolio_file 描述中增加「脚本不会自动读取；若配置，agent 可能按用户指令读取，请勿指向含敏感信息的文件」
- 回应 ClawHub Instruction Scope 检测相关警示

## [1.0.2] - 2026-03-18

### Fixed
- SKILL.md frontmatter 添加 `metadata.openclaw.requires.bins` 声明运行时依赖（curl, iconv, bc）
- SKILL.md frontmatter 添加 `tools: [shell]` 声明使用的工具类型
- skill.yaml 添加 `repository` 字段指向源码仓库
- clawhub.json 添加 `repository` 字段
- 解决 ClawHub 安全扫描标记的"未声明二进制依赖"和"缺少源码仓库 URL"问题

## [1.0.1] - 2026-03-18

### Fixed
- 替换示例中的个人持仓数据为通用虚构数据

## [1.0.0] - 2026-03-18

### Added
- 沪深股票/ETF 实时行情查询（新浪财经数据源）
- 场外基金估值/净值查询（天天基金数据源）
- 智能代码识别：自动判断沪市/深市/场外基金
- 市场前缀防碰撞校验（沪深同号不同标的的安全处理）
- 批量查询支持
- 涨跌 emoji 标识（🔴 上涨 🟢 下跌 ⚪ 平盘）
- QDII 基金净值延迟自动标注
- 持仓市值计算与浮盈/亏展示
- GBK→UTF-8 自动编码转换
- query_price.sh 命令行批量查询脚本
- monitor.sh 接口可用性监控脚本
- 东方财富净值 API 作为备用数据源
