#!/usr/bin/env bash
# Shared helpers for hooks. Works in Git Bash (Windows) and Linux; jq/python are optional.
HOOK_INPUT="$(cat)"
ROOT="${CLAUDE_PROJECT_DIR:-$(pwd)}"

# json_field <dotted.path>  e.g. tool_input.file_path
json_field() {
  local path="$1" key="${1##*.}"
  if command -v jq >/dev/null 2>&1; then
    jq -r ".${path} // empty" <<<"$HOOK_INPUT" 2>/dev/null
  elif command -v python3 >/dev/null 2>&1; then
    python3 -c 'import sys,json
d=json.loads(sys.stdin.read())
for k in sys.argv[1].split("."): d=d.get(k,{}) if isinstance(d,dict) else {}
print(d if isinstance(d,str) else "")' "$path" <<<"$HOOK_INPUT" 2>/dev/null
  else  # last resort: first "key":"value" occurrence
    sed -n "s/.*\"${key}\"[[:space:]]*:[[:space:]]*\"\(\([^\"\\\\]\|\\\\.\)*\)\".*/\1/p" <<<"$HOOK_INPUT" | head -1 | sed 's/\\\\/\\/g; s/\\"/"/g'
  fi
}

# Normalise a path to forward slashes (Windows paths come as C:\...)
norm_path() { printf '%s' "$1" | tr '\\' '/'; }

# PreToolUse decision helpers (exit 0 + JSON)
decide() { # decide <allow|deny|ask> <reason>
  local reason="${2//\"/\'}"
  printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"%s","permissionDecisionReason":"%s"}}\n' "$1" "$reason"
  exit 0
}
