#!/bin/bash
set -euo pipefail

state_dir="$HOME/.cache/playwright-secrets-mcp"
config="$state_dir/config.json"
mkdir -p "$state_dir"

builtin_display_window_bounds() {
  /usr/bin/swift -e '
import AppKit
guard let primary = NSScreen.screens.first else { exit(0) }
for screen in NSScreen.screens {
  let id = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as! UInt32
  guard CGDisplayIsBuiltin(id) != 0 else { continue }
  let f = screen.visibleFrame
  let top = primary.frame.height - (f.origin.y + f.height)
  print(Int(f.origin.x), Int(top), Int(f.width), Int(f.height))
}
' 2>/dev/null | head -1
}

read -r x y width height <<<"$(builtin_display_window_bounds)" || true

if [ -n "${x:-}" ]; then
  cat >"$config" <<JSON
{
  "browser": {
    "launchOptions": {
      "headless": false,
      "args": ["--window-position=${x},${y}", "--window-size=${width},${height}"]
    }
  }
}
JSON
  echo "$(date '+%F %T') built-in display: position=${x},${y} size=${width}x${height}"
  exec npx -y @playwright/mcp@latest --config "$config" "$@"
fi

echo "$(date '+%F %T') built-in display: none"
exec npx -y @playwright/mcp@latest "$@"
