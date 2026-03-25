# stock-query 项目规范

## 仓库结构

这是一个发布到 ClawHub 的 openclaw skill，支持查询全球主要市场股票行情（A 股、港股、美股）、ETF、场外基金及主要指数，同时提供 Claude Code 原生格式，当前为双格式：

| 路径 | 格式 | 触发方式 |
|------|------|---------|
| `SKILL.md` + `skill.yaml` | OpenClaw | 自然语言关键词，`npx clawhub install` 安装 |
| `claude/SKILL.md` | Claude Code 原生 | `/stock-query` slash command |

> ⚠️ `claude/`（无点号）不是 Claude Code 标准 skill 路径。标准路径为 `.claude/skills/stock-query/SKILL.md`。当前状态待验证是否真正注册为 slash command。

## 修改规范

**修改 skill 逻辑时，两个 SKILL.md 必须同步更新：**
- `SKILL.md`（根目录）— OpenClaw 格式
- `claude/SKILL.md` — Claude Code 原生格式

两者的 skill 内容应保持一致，不允许功能分叉。

## 版本与发布

- 版本号需在三处同步维护：`skill.yaml`、`SKILL.md`（frontmatter）、`claude/SKILL.md`（frontmatter）（`clawhub.json` 仅作本地参考，不参与发布）
- 注意：两个 SKILL.md 的 Step 0 正文含硬编码版本字符串（`stock-query vX.X.X`），bump 时需用 `replace_all` 一并替换
- **ClawHub 发布**：只在 openclaw skill（`skill.yaml`、根目录 `SKILL.md`）有实质功能变化时才执行；`claude/` 目录的改动不需要触发 ClawHub 发布

### ClawHub 安全扫描注意事项

- 扫描器对比 SKILL.md 正文内容与元数据声明；SKILL.md 中使用的命令行工具必须在正文"前置依赖"章节明确列出
- `skill.yaml requires.bins` 只列 skill 指令实际调用的二进制（`curl`、`iconv`）；`scripts/` 独立脚本的依赖（如 `bc`）不属于 skill 依赖，不要列入

### ClawHub 发布流程

```bash
mkdir -p /tmp/stock-query
cp SKILL.md skill.yaml /tmp/stock-query/
cp -r examples /tmp/stock-query/
npx clawhub publish /tmp/stock-query --version X.X.X --slug stock-query
rm -rf /tmp/stock-query
```

- `examples/` 需要一并发布，install 时会将其安装到 skill 目录
- `scripts/` 是独立工具脚本，skill 运行不依赖它们，无需发布

## 测试

```bash
make test              # unit + integration（日常开发）
make test-unit         # 仅 unit（无网络，纯本地）
make test-integration  # 仅 integration（真实 API 调用）
make test-e2e          # openclaw agent --local 端到端（需 .env.local 配置 ANTHROPIC_API_KEY）
```

- 测试配置：复制 `.env.local.example` 为 `.env.local`，按需填入
- fixture 数据在 `tests/fixtures/`，从真实 API 响应采集

## 关键目录与文件

| 路径 | 用途 |
|------|------|
| `scripts/` | 独立可执行脚本（query_price.sh 批量查询、monitor.sh 接口监控） |
| `tests/` | 三层测试：unit/integration/e2e |
| `claude/` | Claude Code 原生格式 skill |
| `examples/portfolio.csv` | 自选股/持仓文件示例模板，随 skill 一起安装到 skill 目录 |

### portfolio_file 使用规范

- 用户实际文件路径：`{skill_install_dir}/portfolio.csv`（不存在时 skill 引导用户从 `examples/portfolio.csv` 复制创建，install.sh 不自动创建）
- **install.sh 行为应与 clawhub 安装保持一致**：只装 `SKILL.md` + `examples/`，不做用户文件初始化
- 格式：CSV，表头 `代码,名称,持仓,成本价`，`#` 开头为注释行
- 名称/持仓/成本价均可留空；持仓为 0 表示纯自选（只查行情）
- 修改 Step 6 逻辑时，6a（文件加载）和 6b（手动输入）均需同步维护
- `examples/portfolio.csv` 随 skill 一起发布，install.sh 和 clawhub 安装后均可在 skill 目录下找到

## 数据源

- **腾讯财经**（`qt.gtimg.cn`）— 首选，支持 A 股/港股/美股，GBK 编码，`~` 分隔字段
- **新浪财经**（`hq.sinajs.cn`）— A 股备用，GBK 编码，`,` 分隔字段，需 `Referer` header
- 两者响应均需 `| iconv -f GBK -t UTF-8` 转码

腾讯 API 前缀：`sh`/`sz`(A股) · `hk`(港股5位) · `us`+ticker(美股) · `us.XXX`(美股指数)
腾讯字段索引（`~` 分隔）：[1]名称 [3]最新价 [4]昨收 [30]日期时间 [31]涨跌额 [32]涨跌幅% [33]最高 [34]最低
频率限制：≤100 代码/次，间隔 ≥100ms，过度调用封 IP

## 测试 fixtures

- `tests/fixtures/tencent_*.txt` — 从真实 API 响应采集，字段随实时数据变化（涨跌数值会变，结构不变）
- fixture 更新方式：`curl -s "https://qt.gtimg.cn/q=sh600519" | iconv -f GBK -t UTF-8 | sed 's/;$//'`
