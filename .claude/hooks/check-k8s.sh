#!/usr/bin/env bash
# PostToolUse(Edit|Write): validate Kubernetes / Argo CD YAML right after it is edited.
# Exit 2 => problems are shown to Claude so it fixes them immediately.
source "$(dirname "$0")/lib.sh"
file="$(norm_path "$(json_field tool_input.file_path)")"
case "$file" in */k8s/*.y*ml|*/argocd/*.y*ml|k8s/*.y*ml|argocd/*.y*ml) ;; *) exit 0 ;; esac
cd "$ROOT" || exit 0
problems=""

# 1. YAML syntax
if command -v python3 >/dev/null 2>&1 && python3 -c 'import yaml' 2>/dev/null; then
  err="$(python3 -c 'import sys,yaml; list(yaml.safe_load_all(open(sys.argv[1])))' "$file" 2>&1)" || problems+="YAML syntax error in $file: ${err##*$'\n'}"$'\n'
fi
# 2. Image policy
grep -nE 'saiupadhyayula007/' "$file" >/dev/null && problems+="$file uses saiupadhyayula007/* (arm64-only) images."$'\n'
case "$file" in */overlays/*)
  grep -nE 'newTag:[[:space:]]*"?latest"?' "$file" >/dev/null && problems+="$file: newTag 'latest' is not allowed; pin a version."$'\n' ;;
esac
# 3. Render all kustomizations (client-side only, no cluster needed)
if command -v kubectl >/dev/null 2>&1; then
  for k in k8s/infrastructure/core k8s/infrastructure/extras k8s/apps/overlays/local k8s/apps/overlays/full; do
    [ -f "$k/kustomization.yaml" ] || continue
    out="$(timeout 30 kubectl kustomize "$k" 2>&1 >/dev/null)" || problems+="kubectl kustomize $k failed: $out"$'\n'
  done
fi

if [ -n "$problems" ]; then
  printf 'k8s check failed:\n%s' "$problems" >&2
  exit 2
fi
exit 0
