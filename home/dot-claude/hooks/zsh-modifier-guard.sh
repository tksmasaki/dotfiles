#!/bin/sh
# PreToolUse(Bash) フック。zsh は二重引用符の中でも `$B:config/x` の `:c` を修飾子として解釈し、
# `mainonfig/x` に黙って化けるため、展開される位置の `$名前:修飾子` を拒否する。
set -eu

exec python3 -I -c '
import json
import re
import sys

command = (json.load(sys.stdin).get("tool_input") or {}).get("command") or ""

unexpanded_heredoc = re.compile(r"<<-?\s*([\x27\"])(\w+)\1[^\n]*\n.*?^\s*\2\s*$", re.S | re.M)
command = unexpanded_heredoc.sub(" ", command)

expanded = []
quote = None
i = 0
while i < len(command):
    c = command[i]
    if c == "\\":
        i += 2
        continue
    if quote is None and c == "\x27":
        end = command.find("\x27", i + 1)
        i = len(command) if end < 0 else end + 1
        continue
    if c == "\"":
        quote = None if quote else c
    expanded.append(c)
    i += 1

match = re.search(r"\$([A-Za-z_][A-Za-z0-9_]*|[0-9]):[aAcehlpPqQrsStux&]", "".join(expanded))
if match:
    name = match.group(1)
    print(json.dumps({
        "hookSpecificOutput": {
            "hookEventName": "PreToolUse",
            "permissionDecision": "deny",
            "permissionDecisionReason": f"zsh は `${name}:` の直後の英字を修飾子として解釈し、別の値に化ける（例: `$B:config/x` が `mainonfig/x` になる）。二重引用符の中でも起きる。`${{{name}}}:` と波括弧で囲んで書き直す。",
        }
    }, ensure_ascii=False))
'
