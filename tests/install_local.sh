#!/usr/bin/env bash
# tests/install_local.sh
# 将当前开发内容同步到本地 OpenClaw skill 目录，供发布前测试使用。
# 不走 clawhub publish，直接覆盖安装目录中的文件。
# 测试通过后再执行 clawhub publish（见 CLAUDE.md「ClawHub 发布流程」）。
#
# 用法：bash tests/install_local.sh [--dir <skill_dir>]
#
# 默认目标目录：~/.openclaw/workspace/skills/stock-query
# 覆盖示例：bash tests/install_local.sh --dir ~/.openclaw-dev/workspace/skills/stock-query

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# ── 解析参数 ──────────────────────────────────────────────────────────────────
SKILL_DIR="${HOME}/.openclaw/workspace/skills/stock-query"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dir) SKILL_DIR="$2"; shift 2 ;;
    *) echo "unknown option: $1" >&2; exit 1 ;;
  esac
done

# ── 前置检查 ──────────────────────────────────────────────────────────────────
if [ ! -d "$SKILL_DIR" ]; then
  echo "目标目录不存在：$SKILL_DIR"
  echo "请先通过 clawhub 安装一次：npx clawhub install stock-query"
  exit 1
fi

# ── 同步文件（与 clawhub publish 发布内容保持一致）────────────────────────────
cp "$PROJECT_ROOT/SKILL.md"                "$SKILL_DIR/SKILL.md"
cp "$PROJECT_ROOT/skill.yaml"              "$SKILL_DIR/skill.yaml"
cp "$PROJECT_ROOT/scripts/portfolio.sh"    "$SKILL_DIR/portfolio.sh"
chmod +x "$SKILL_DIR/portfolio.sh"

# examples/ 整目录同步（保留目标目录中用户自建文件，只覆盖 examples/）
cp -r "$PROJECT_ROOT/examples" "$SKILL_DIR/"

# ── 读取版本号并输出结果 ──────────────────────────────────────────────────────
version=$(grep '^version:' "$PROJECT_ROOT/skill.yaml" | awk '{print $2}')
printf "[OK] stock-query v%s -> %s\n" "$version" "$SKILL_DIR"
echo ""
echo "下一步：在 OpenClaw 中开启新 session 后执行测试（skill 在 session 启动时加载）"
