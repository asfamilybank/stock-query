#!/usr/bin/env bash
# stock-query Claude Code skill installer
# Usage: curl -fsSL https://raw.githubusercontent.com/asfamilybank/stock-query/main/install.sh | bash
#        curl -fsSL https://raw.githubusercontent.com/asfamilybank/stock-query/main/install.sh | bash -s -- --project

set -e

REPO="asfamilybank/stock-query"
BRANCH="main"
SKILL_NAME="stock-query"
SKILL_FILE_URL="https://raw.githubusercontent.com/${REPO}/${BRANCH}/claude/SKILL.md"

# Parse args
PROJECT_INSTALL=false
for arg in "$@"; do
  case "$arg" in
    --project|-p) PROJECT_INSTALL=true ;;
    --help|-h)
      echo "Usage: install.sh [--project]"
      echo "  (no flag)   Install globally to ~/.claude/skills/${SKILL_NAME}/"
      echo "  --project   Install to current project's .claude/skills/${SKILL_NAME}/"
      exit 0
      ;;
  esac
done

if $PROJECT_INSTALL; then
  INSTALL_DIR=".claude/skills/${SKILL_NAME}"
  SCOPE="project"
else
  INSTALL_DIR="${HOME}/.claude/skills/${SKILL_NAME}"
  SCOPE="global"
fi

# Check for curl
if ! command -v curl &>/dev/null; then
  echo "Error: curl is required but not found." >&2
  exit 1
fi

# Extract version from a SKILL.md file
extract_version() {
  grep '^version:' "$1" 2>/dev/null | awk '{print $2}' | tr -d '"'
}

# Download remote SKILL.md to temp file
TMP_FILE="$(mktemp)"
trap 'rm -f "${TMP_FILE}"' EXIT

echo "正在获取最新版本信息..."
curl -fsSL "${SKILL_FILE_URL}" -o "${TMP_FILE}"

REMOTE_VERSION="$(extract_version "${TMP_FILE}")"
REMOTE_VERSION="${REMOTE_VERSION:-unknown}"

LOCAL_SKILL="${INSTALL_DIR}/SKILL.md"

if [ -f "${LOCAL_SKILL}" ]; then
  LOCAL_VERSION="$(extract_version "${LOCAL_SKILL}")"
  LOCAL_VERSION="${LOCAL_VERSION:-unknown}"

  echo "当前已安装版本：v${LOCAL_VERSION}"
  echo "最新版本：      v${REMOTE_VERSION}"
  echo ""

  if [ "${LOCAL_VERSION}" = "${REMOTE_VERSION}" ]; then
    echo "已是最新版本，无需更新。"
    exit 0
  fi

  cp "${TMP_FILE}" "${LOCAL_SKILL}"
  echo "已更新至最新版本 v${REMOTE_VERSION}（原版本 v${LOCAL_VERSION}）"
else
  mkdir -p "${INSTALL_DIR}"
  cp "${TMP_FILE}" "${LOCAL_SKILL}"
  echo "已安装 stock-query v${REMOTE_VERSION}（${SCOPE}）"
  echo ""
  echo "使用方式："
  echo "  /stock-query AAPL 00700 601991"
fi
