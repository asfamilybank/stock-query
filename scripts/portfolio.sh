#!/usr/bin/env bash
# portfolio.sh — 自选股文件增删改查
#
# Usage:
#   portfolio.sh list
#   portfolio.sh add  <code> [--name <name>] [--shares <n>] [--cost <price>]
#   portfolio.sh edit <code> [--name <name>] [--shares <n>] [--cost <price>]
#   portfolio.sh delete <code>
#   portfolio.sh path
#
# 输出格式（stdout）：
#   list   → 原始 CSV 内容
#   add    → ADDED:{csv_row}
#   edit   → BEFORE:{old_row}\nAFTER:{new_row}
#   delete → DELETED:{csv_row}
#   path   → 文件绝对路径
#
# 错误（stderr + exit 1）：
#   ERROR:FILE_NOT_FOUND
#   ERROR:MISSING_CODE
#   ERROR:DUPLICATE:{code}
#   ERROR:NOT_FOUND:{code}

set -uo pipefail

# --- 文件定位 ---
find_portfolio() {
  local candidates=(
    "${HOME}/.openclaw/workspace/skills/stock-query/portfolio.csv"
    "${HOME}/.claude/skills/stock-query/portfolio.csv"
    ".claude/skills/stock-query/portfolio.csv"
  )
  for p in "${candidates[@]}"; do
    if [[ -f "$p" ]]; then echo "$p"; return 0; fi
  done
  echo "ERROR:FILE_NOT_FOUND" >&2
  return 1
}

# 在文件中按代码查找行号（跳过注释行和表头）
find_code_line() {
  local file="$1" code="$2"
  awk -F',' -v code="$code" \
    'NR>1 && !/^[[:space:]]*#/ && $1==code {print NR; exit}' "$file"
}

# --- 主逻辑 ---

CMD="${1:-}"
shift || true

case "$CMD" in

  path)
    find_portfolio
    ;;

  list)
    FILE=$(find_portfolio) || exit 1
    cat "$FILE"
    ;;

  add)
    CODE="${1:-}"; shift || true
    [[ -z "$CODE" ]] && { echo "ERROR:MISSING_CODE" >&2; exit 1; }
    NAME="" SHARES="" COST=""
    while [[ $# -gt 0 ]]; do
      case "$1" in
        --name)   NAME="$2";   shift 2 ;;
        --shares) SHARES="$2"; shift 2 ;;
        --cost)   COST="$2";   shift 2 ;;
        *) shift ;;
      esac
    done
    FILE=$(find_portfolio) || exit 1
    # 检查重复
    if awk -F',' -v code="$CODE" \
      'NR>1 && !/^[[:space:]]*#/ && $1==code {found=1} END {exit !found}' "$FILE"; then
      echo "ERROR:DUPLICATE:${CODE}" >&2; exit 1
    fi
    NEW_ROW="${CODE},${NAME},${SHARES},${COST}"
    echo "$NEW_ROW" >> "$FILE"
    echo "ADDED:${NEW_ROW}"
    ;;

  edit)
    CODE="${1:-}"; shift || true
    [[ -z "$CODE" ]] && { echo "ERROR:MISSING_CODE" >&2; exit 1; }
    NAME="" SHARES="" COST=""
    while [[ $# -gt 0 ]]; do
      case "$1" in
        --name)   NAME="$2";   shift 2 ;;
        --shares) SHARES="$2"; shift 2 ;;
        --cost)   COST="$2";   shift 2 ;;
        *) shift ;;
      esac
    done
    FILE=$(find_portfolio) || exit 1
    LINE_NUM=$(find_code_line "$FILE" "$CODE")
    [[ -z "$LINE_NUM" ]] && { echo "ERROR:NOT_FOUND:${CODE}" >&2; exit 1; }
    OLD_ROW=$(sed -n "${LINE_NUM}p" "$FILE")
    OLD_NAME=$(echo "$OLD_ROW"   | cut -d',' -f2)
    OLD_SHARES=$(echo "$OLD_ROW" | cut -d',' -f3)
    OLD_COST=$(echo "$OLD_ROW"   | cut -d',' -f4)
    NEW_NAME="${NAME:-${OLD_NAME}}"
    NEW_SHARES="${SHARES:-${OLD_SHARES}}"
    NEW_COST="${COST:-${OLD_COST}}"
    NEW_ROW="${CODE},${NEW_NAME},${NEW_SHARES},${NEW_COST}"
    TMP=$(mktemp)
    awk -v line="$LINE_NUM" -v new_row="$NEW_ROW" \
      'NR==line {print new_row; next} {print}' "$FILE" > "$TMP" && mv "$TMP" "$FILE"
    echo "BEFORE:${OLD_ROW}"
    echo "AFTER:${NEW_ROW}"
    ;;

  delete)
    CODE="${1:-}"
    [[ -z "$CODE" ]] && { echo "ERROR:MISSING_CODE" >&2; exit 1; }
    FILE=$(find_portfolio) || exit 1
    LINE_NUM=$(find_code_line "$FILE" "$CODE")
    [[ -z "$LINE_NUM" ]] && { echo "ERROR:NOT_FOUND:${CODE}" >&2; exit 1; }
    DELETED_ROW=$(sed -n "${LINE_NUM}p" "$FILE")
    TMP=$(mktemp)
    awk -v line="$LINE_NUM" 'NR!=line {print}' "$FILE" > "$TMP" && mv "$TMP" "$FILE"
    echo "DELETED:${DELETED_ROW}"
    ;;

  *)
    echo "Usage: portfolio.sh <list|add|edit|delete|path>" >&2
    exit 1
    ;;
esac
