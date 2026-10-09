#!/usr/bin/env bash
# PostToolUse(Edit|Write): format the edited Java file with Spotless (palantir-java-format, configured in root pom.xml).
# Non-blocking: if Maven is missing or offline, it silently skips.
source "$(dirname "$0")/lib.sh"
file="$(norm_path "$(json_field tool_input.file_path)")"
case "$file" in *.java) ;; *) exit 0 ;; esac
command -v mvn >/dev/null 2>&1 || exit 0

# module = services/<name>
module="$(sed -n 's#.*/\(services/[^/]*\)/src/.*#\1#p' <<<"$file")"
[ -z "$module" ] && exit 0
cd "$ROOT" || exit 0
regex=".*$(basename "$file" | sed 's/\./\\./g')"
if timeout 120 mvn -q -B -pl "$module" com.diffplug.spotless:spotless-maven-plugin:apply -DspotlessFiles="$regex" >/dev/null 2>&1; then
  echo "Formatted $(basename "$file") with Spotless."
fi
exit 0
