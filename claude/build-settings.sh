#!/bin/sh
set -eu

base="$(dirname "$0")/settings.base.json"
local_dir="${HOME}/.config/claude"

if ! command -v jq >/dev/null 2>&1; then
  cat "${base}"
  exit 0
fi

read_json() {
  if [ -f "$1" ]; then cat "$1"; else printf '%s' "$2"; fi
}

jq \
  --argjson env "$(read_json "${local_dir}/env.json" '{}')" \
  --argjson plugins "$(read_json "${local_dir}/plugins.json" '{}')" \
  --argjson denied "$(read_json "${local_dir}/denied-mcp-servers.json" 'null')" \
  '.env += $env
   | .enabledPlugins += $plugins
   | if $denied == null then . else .deniedMcpServers = $denied end' \
  "${base}"
