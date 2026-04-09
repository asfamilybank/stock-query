#!/usr/bin/env bash
# bump.sh — 版本号管理工具（同步更新 skill.yaml / SKILL.md / clawhub.json）
#
# 用法:
#   bash bump.sh alpha                      # 递增预发布号: X.Y.Z-alpha.N → X.Y.Z-alpha.(N+1)
#   bash bump.sh <major|minor|patch> alpha  # 从正式版开启新预发布: X.Y.Z → X'.Y'.Z'-alpha.1
#   bash bump.sh release                    # 预发布 → 正式版: X.Y.Z-alpha.N → X.Y.Z
#   bash bump.sh <major|minor|patch>        # 正式版递增: X.Y.Z → X'.Y'.Z'
#   bash bump.sh <X.Y.Z[-alpha.N]>          # 直接设定版本号

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

SKILL_YAML="$ROOT/skill.yaml"
SKILL_MD="$ROOT/SKILL.md"
CLAWHUB_JSON="$ROOT/clawhub.json"

# ── 工具函数 ──────────────────────────────────────────────────────────────────

err()  { printf '[error] %s\n' "$*" >&2; exit 1; }
ok()   { printf '[ok] %s\n' "$*"; }

sed_i() {
  if sed --version 2>/dev/null | grep -q GNU; then
    sed -i "$@"
  else
    sed -i '' "$@"
  fi
}

usage() {
  cat >&2 <<'EOF'
用法:
  bump.sh alpha                      递增预发布号（当前须为预发布版）
  bump.sh <major|minor|patch> alpha  从正式版开启新预发布
  bump.sh release                    预发布 → 正式版
  bump.sh <major|minor|patch>        正式版递增
  bump.sh <X.Y.Z[-alpha.N]>          直接设定版本号
EOF
  exit 1
}

# ── 文件检查 ──────────────────────────────────────────────────────────────────

[[ -f "$SKILL_YAML" ]]   || err "找不到 $SKILL_YAML"
[[ -f "$SKILL_MD" ]]     || err "找不到 $SKILL_MD"
[[ -f "$CLAWHUB_JSON" ]] || err "找不到 $CLAWHUB_JSON"

# ── 读取并解析当前版本 ────────────────────────────────────────────────────────

CURRENT=$(grep '^version:' "$SKILL_YAML" | awk '{print $2}' | tr -d "'\"")
[[ -n "$CURRENT" ]] || err "无法从 skill.yaml 读取版本号"

MAJOR=0; MINOR=0; PATCH=0; ALPHA=0; IS_ALPHA=false

if [[ "$CURRENT" =~ ^([0-9]+)\.([0-9]+)\.([0-9]+)-alpha\.([0-9]+)$ ]]; then
  MAJOR="${BASH_REMATCH[1]}"
  MINOR="${BASH_REMATCH[2]}"
  PATCH="${BASH_REMATCH[3]}"
  ALPHA="${BASH_REMATCH[4]}"
  IS_ALPHA=true
elif [[ "$CURRENT" =~ ^([0-9]+)\.([0-9]+)\.([0-9]+)$ ]]; then
  MAJOR="${BASH_REMATCH[1]}"
  MINOR="${BASH_REMATCH[2]}"
  PATCH="${BASH_REMATCH[3]}"
else
  err "版本格式无法解析：$CURRENT（期望 X.Y.Z 或 X.Y.Z-alpha.N）"
fi

# ── 计算新版本 ────────────────────────────────────────────────────────────────

[[ $# -eq 0 ]] && usage

NEW=""
CMD1="${1:-}"
CMD2="${2:-}"

case "$CMD1" in
  alpha)
    [[ "$IS_ALPHA" == true ]] \
      || err "当前版本 $CURRENT 是正式版，需指定类型，例如: bump.sh minor alpha"
    NEW="${MAJOR}.${MINOR}.${PATCH}-alpha.$((ALPHA + 1))"
    ;;

  release)
    [[ "$IS_ALPHA" == true ]] \
      || err "当前版本 $CURRENT 已是正式版，无法执行 release"
    NEW="${MAJOR}.${MINOR}.${PATCH}"
    ;;

  major|minor|patch)
    if [[ "$CMD2" == "alpha" ]]; then
      [[ "$IS_ALPHA" == false ]] \
        || err "当前版本 $CURRENT 已在预发布中，请先执行 release 后再开启新预发布"
      case "$CMD1" in
        major) NEW="$((MAJOR + 1)).0.0-alpha.1" ;;
        minor) NEW="${MAJOR}.$((MINOR + 1)).0-alpha.1" ;;
        patch) NEW="${MAJOR}.${MINOR}.$((PATCH + 1))-alpha.1" ;;
      esac
    elif [[ -z "$CMD2" ]]; then
      [[ "$IS_ALPHA" == false ]] \
        || err "当前版本 $CURRENT 是预发布版，正式递增前请先执行 release"
      case "$CMD1" in
        major) NEW="$((MAJOR + 1)).0.0" ;;
        minor) NEW="${MAJOR}.$((MINOR + 1)).0" ;;
        patch) NEW="${MAJOR}.${MINOR}.$((PATCH + 1))" ;;
      esac
    else
      usage
    fi
    ;;

  *)
    # 直接设定版本号
    if [[ "$CMD1" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-alpha\.[0-9]+)?$ ]]; then
      NEW="$CMD1"
    else
      usage
    fi
    ;;
esac

[[ -n "$NEW" ]] || err "内部错误：未能计算新版本号"
[[ "$NEW" != "$CURRENT" ]] || err "新版本与当前版本相同：$CURRENT"

# ── 更新四处 ──────────────────────────────────────────────────────────────────

# skill.yaml
sed_i "s/^version: ${CURRENT}/version: ${NEW}/" "$SKILL_YAML"

# SKILL.md frontmatter（metadata.version，带缩进和引号）
sed_i "s/  version: \"${CURRENT}\"/  version: \"${NEW}\"/" "$SKILL_MD"

# SKILL.md 正文（stock-query vX.X.X，可能多处）
sed_i "s/stock-query v${CURRENT}/stock-query v${NEW}/g" "$SKILL_MD"

# clawhub.json
sed_i "s/\"version\": \"${CURRENT}\"/\"version\": \"${NEW}\"/" "$CLAWHUB_JSON"

# ── 验证一致性 ────────────────────────────────────────────────────────────────

check() {
  local file="$1" pattern="$2"
  grep -q "$pattern" "$file" || printf '[warn] %s 未找到版本字符串，请手动检查\n' "$file" >&2
}

check "$SKILL_YAML"   "^version: ${NEW}"
check "$SKILL_MD"     "  version: \"${NEW}\""
check "$CLAWHUB_JSON" "\"version\": \"${NEW}\""

ok "${CURRENT} → ${NEW}"
