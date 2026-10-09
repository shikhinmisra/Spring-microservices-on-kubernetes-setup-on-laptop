#!/usr/bin/env bash
# PreToolUse(Bash): enforce the project's always-on rules before a shell command runs.
source "$(dirname "$0")/lib.sh"
cmd="$(json_field tool_input.command)"
[ -z "$cmd" ] && exit 0

# --- hard denies ---------------------------------------------------------
# Checks look at the actual command segment (up to | ; & or newline), so prose inside heredocs/commit messages doesn't trigger them.
if grep -qE '\b(docker|kubectl|helm|crane|skopeo)\b[^|;&]*saiupadhyayula007/' <<<"$cmd"; then
  decide deny "saiupadhyayula007/* images are arm64-only and crash on this x64 laptop. Build locally and use localhost:30002/microservices/<svc>:<tag>."
fi
if grep -qE '(^|[[:space:];&|(])(\./)?mvnw?[[:space:]][^|;&]*(-DskipTests|maven\.test\.skip)' <<<"$cmd"; then
  decide deny "Project rule: never skip tests. Run 'mvn -pl services/<svc> -am verify' and report failures."
fi
if grep -qE 'kubectl[^|;&]*\bapply\b' <<<"$cmd"; then
  # every -f/--filename argument must be a single manifest file (or stdin "-"); folders are not allowed
  while read -r target; do
    [ -z "$target" ] && continue
    case "$target" in -|*.yml|*.yaml|*.json|http*://*) ;; *)
      decide deny "Never 'kubectl apply -f' a folder ($target) - it re-enables everything and can freeze the laptop. Use 'kubectl apply -k <kustomization dir>' or scripts/windows/deploy.ps1." ;;
    esac
  done < <(grep -oE 'kubectl[^|;&]*\bapply\b[^|;&]*' <<<"$cmd" | grep -oE '(-f|--filename)[ =]+[^ ;|&]+' | sed -E 's/^(-f|--filename)[ =]+//')
  grep -qE 'kubectl[^|;&]*\bapply\b[^|;&]*(-R|--recursive)\b' <<<"$cmd" && decide deny "Recursive 'kubectl apply' is not allowed; use 'kubectl apply -k'."
fi

# --- needs the user's OK -------------------------------------------------
if grep -qE 'kubectl[^|;&]*\b(delete)\b' <<<"$cmd"; then
  decide ask "Deleting Kubernetes resources requires the user's approval (CLAUDE.md)."
fi
if grep -qE 'helm[^|;&]*\b(uninstall|delete)\b' <<<"$cmd"; then
  decide ask "helm uninstall requires the user's approval (CLAUDE.md)."
fi
if grep -qE 'kubectl[^|;&]*\bapply\b[^|;&]*-k[ =]*[^ ]*(infrastructure/extras|overlays/full)' <<<"$cmd"; then
  decide ask "extras/full need ~8-10 GB; default is backend only. Check memory and get the user's OK first."
fi
if grep -qE 'git[^|;&]*push[^|;&]*(--force|-f\b|--force-with-lease)' <<<"$cmd"; then
  decide ask "Force-push requires the user's approval."
fi
if grep -qE '\brm\b[^|;&]*-[a-zA-Z]*r' <<<"$cmd" || grep -qE 'wsl(\.exe)?[^|;&]*--(shutdown|unregister)' <<<"$cmd"; then
  decide ask "Recursive delete / WSL shutdown requires the user's approval (CLAUDE.md)."
fi
exit 0
