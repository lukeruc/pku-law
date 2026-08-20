#!/usr/bin/env bash
# pkulaw.sh — 北大法宝 MCP CLI 多密钥故障转移包装器
#
# 用法:
#   ./pkulaw.sh <serverId> <toolName> [位置参数] [--参数 值 ...] [--md|--json]
#   ./pkulaw.sh probe            # 仅探测可用密钥，不执行业务调用
#   ./pkulaw.sh raw <任意pkulaw-mcp子命令及参数>   # 用选中密钥执行任意原生命令
#
# 密钥来源（优先级从高到低）:
#   1. 环境变量 PKULAW_MCP_AUTHORIZATION（单个，完整 Bearer 头）
#   2. 本脚本同目录上级的 auth.env（多密钥，逐个尝试）
#   3. ~/.pkulaw/mcp/config.json（CLI 内置回落，不设环境变量即可）
#
# 退出码: 0 成功；2 所有密钥均失败；3 auth.env 存在但无可用密钥行

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(dirname "$SCRIPT_DIR")"
AUTH_FILE="${PKULAW_AUTH_FILE:-$SKILL_DIR/auth.env}"

# 探测命令：一次最廉价的真实 API 调用，用于验证密钥有效性
PROBE_SERVER="${PKULAW_PROBE_SERVER:-law-keyword}"
PROBE_TOOL="${PKULAW_PROBE_TOOL:-get_law_list}"
PROBE_ARGS=(${PKULAW_PROBE_ARGS:---title 民法典})

# 判定失败：CLI 非零退出码（认证失败/限速/超时/网关异常均非零），辅以错误文案兜底
is_auth_failure() {
  grep -qE '认证失败|status code (401|403|429|5[0-9][0-9])|Request failed|超时|timeout' <<<"$1"
}

# 从 auth.env 解析密钥列表：每行 KEY<数字>='...' 或 KEY<数字>="..."，值可为裸 token（自动补 Bearer）
load_keys() {
  local line id val
  [ -f "$AUTH_FILE" ] || return 0
  while IFS= read -r line; do
    line="$(trim "$line")"
    case "$line" in ''|\#*) continue ;; esac
    if [[ "$line" =~ ^KEY[0-9]+=.*$ ]]; then
      val="${line#*=}"
      val="$(trim "$val")"
      # 剥离成对的单/双引号
      if [[ "$val" =~ ^\'.*\'$ || "$val" =~ ^\".*\"$ ]]; then
        val="${val:1:${#val}-2}"
      fi
      val="$(trim "$val")"
      [[ "$val" =~ ^Bearer\  ]] || val="Bearer $val"
      [ -n "$val" ] && echo "$val"
    fi
  done < "$AUTH_FILE"
}

trim() { sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' <<<"$1"; }

# 依优先级组装候选密钥序列（可能为空 = 回落到 config.json）
candidates=()
[ -n "${PKULAW_MCP_AUTHORIZATION:-}" ] && candidates+=("$PKULAW_MCP_AUTHORIZATION")
while IFS= read -r k; do candidates+=("$k"); done < <(load_keys)

probe_with() {
  local key="$1" out rc
  out="$(PKULAW_MCP_AUTHORIZATION="$key" pkulaw-mcp "$PROBE_SERVER" "$PROBE_TOOL" "${PROBE_ARGS[@]}" 2>&1)"
  rc=$?
  # 成功判定：退出码为 0 且无失败文案
  if [ $rc -eq 0 ] && ! is_auth_failure "$out"; then
    return 0
  fi
  return 1
}

# ---------- probe 子命令 ----------
if [ "${1:-}" = "probe" ]; then
  if [ ${#candidates[@]} -eq 0 ]; then
    echo "无环境变量/auth.env密钥，将回落到 ~/.pkulaw/mcp/config.json"
    pkulaw-mcp check && exit 0 || exit 2
  fi
  idx=0
  for k in "${candidates[@]}"; do
    idx=$((idx+1))
    token_hint="$(sed -E 's/^Bearer +//' <<<"$k" | cut -c1-8)…"
    if probe_with "$k"; then
      echo "OK  密钥#$idx ($token_hint) 可用"
    else
      echo "FAIL 密钥#$idx ($token_hint) 不可用"
    fi
  done
  exit 0
fi

# ---------- raw 子命令 ----------
RAW_MODE=0
if [ "${1:-}" = "raw" ]; then
  RAW_MODE=1
  shift
fi

# ---------- 主流程：选密钥并执行 ----------
run_with() {
  local key="$1"; shift
  if [ -n "$key" ]; then
    PKULAW_MCP_AUTHORIZATION="$key" pkulaw-mcp "$@"
  else
    pkulaw-mcp "$@"
  fi
}

SELECTED=""
if [ ${#candidates[@]} -eq 0 ]; then
  # 无候选密钥，直接走 config.json
  SELECTED=""
else
  idx=0
  for k in "${candidates[@]}"; do
    idx=$((idx+1))
    token_hint="$(sed -E 's/^Bearer +//' <<<"$k" | cut -c1-8)…"
    if probe_with "$k"; then
      SELECTED="$k"
      echo "使用密钥#$idx ($token_hint)" >&2
      break
    else
      echo "密钥#$idx ($token_hint) 失效/限速，尝试下一个…" >&2
    fi
  done
  if [ -z "$SELECTED" ]; then
    echo "错误: auth.env 中所有密钥均不可用" >&2
    echo "提示: 已自动尝试回落到 config.json 中的密钥" >&2
  fi
fi

run_with "$SELECTED" "$@"
