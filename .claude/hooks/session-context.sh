#!/usr/bin/env bash
# SessionStart: give Claude a short snapshot of repo + cluster state (stdout becomes context). Must stay fast.
source "$(dirname "$0")/lib.sh"
cd "$ROOT" 2>/dev/null || exit 0
echo "## Session snapshot"
if command -v git >/dev/null 2>&1; then
  echo "- git: branch $(git branch --show-current 2>/dev/null), $(git status --porcelain 2>/dev/null | wc -l | tr -d ' ') uncommitted file(s)"
fi
if command -v kubectl >/dev/null 2>&1; then
  if timeout 6 kubectl get --raw /readyz --request-timeout=4s >/dev/null 2>&1; then
    total=$(timeout 6 kubectl get pods --no-headers 2>/dev/null | wc -l | tr -d ' ')
    bad=$(timeout 6 kubectl get pods --no-headers 2>/dev/null | grep -vcE 'Running|Completed')
    echo "- cluster: reachable ($(kubectl config current-context 2>/dev/null)); default ns pods: $total, not running: $bad"
  else
    echo "- cluster: NOT reachable (Docker Desktop stopped or VM overloaded) - use the troubleshoot-cluster skill before deploying"
  fi
fi
if command -v wsl.exe >/dev/null 2>&1; then
  avail=$(timeout 6 wsl.exe -d docker-desktop free -m 2>/dev/null | tr -d '\r' | awk '/^Mem:/{print $7}')
  [ -n "$avail" ] && echo "- docker VM available memory: ${avail} MB (rule: < 2048 MB => add nothing)"
fi
if command -v curl >/dev/null 2>&1; then
  if timeout 4 curl -s http://localhost:30002/api/v2.0/ping 2>/dev/null | grep -q Pong; then echo "- harbor: up"; else echo "- harbor: not reachable from here"; fi
fi
exit 0
