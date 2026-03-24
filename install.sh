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

echo "Installing stock-query Claude Code skill (${SCOPE})..."

# Detect update vs fresh install
if [ -f "${INSTALL_DIR}/SKILL.md" ]; then
  ACTION="Updated"
else
  ACTION="Installed"
  mkdir -p "${INSTALL_DIR}"
fi

curl -fsSL "${SKILL_FILE_URL}" -o "${INSTALL_DIR}/SKILL.md"

echo ""
echo "${ACTION} successfully: ${INSTALL_DIR}/SKILL.md"
echo ""
echo "Usage in Claude Code:"
echo "  /stock-query AAPL 00700 601991"
