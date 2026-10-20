#!/bin/sh
# Stop hook。このターンでユーザーに見せた文（本文と wrap_up の recap・ask・ボタン）が日本語でなければ、
# 書き直させるためにターンの終了を止める。止めた後の 2 回目（stop_hook_active）は通し、無限に止めない。
set -eu

exec python3 -I -c '
import json
import re
import sys

payload = json.load(sys.stdin)
if payload.get("stop_hook_active"):
    sys.exit(0)

path = payload.get("transcript_path")
if not path:
    sys.exit(0)

entries = []
with open(path, encoding="utf-8") as f:
    for line in f:
        try:
            entries.append(json.loads(line))
        except ValueError:
            pass


def is_user_prompt(entry):
    if entry.get("type") != "user" or entry.get("isMeta"):
        return False
    content = (entry.get("message") or {}).get("content")
    if isinstance(content, str):
        return True
    return isinstance(content, list) and not any(b.get("type") == "tool_result" for b in content)


start = max((i for i, e in enumerate(entries) if is_user_prompt(e)), default=-1) + 1
texts = []
for entry in entries[start:]:
    if entry.get("type") != "assistant":
        continue
    for block in (entry.get("message") or {}).get("content") or []:
        if block.get("type") == "text":
            texts.append(block.get("text", ""))
        elif block.get("type") == "tool_use" and block.get("name", "").endswith("__wrap_up"):
            data = block.get("input") or {}
            texts += [data.get("recap", ""), data.get("ask", "")]
            for action in data.get("actions") or []:
                if isinstance(action, dict):
                    texts += [action.get("label", ""), action.get("message", "")]

prose = "\n".join(t for t in texts if t)
prose = re.sub(r"```.*?```", " ", prose, flags=re.S)
prose = re.sub(r"`[^`]*`", " ", prose)
prose = re.sub(r"https?://\S+|\S*/\S+", " ", prose)

japanese = len(re.findall(r"[぀-ヿ㐀-鿿ｦ-ﾟ]", prose))
latin = len(re.findall(r"[A-Za-z]", prose))

if latin >= 40 and japanese < latin * 0.3:
    print(json.dumps({
        "decision": "block",
        "reason": "このターンでユーザーに見せた文（本文、wrap_up の recap・ask・ボタン）が日本語になっていない。"
                  "ユーザーの設定は「出力は日本語」。同じ内容を日本語で書き直して、もう一度伝える。",
    }, ensure_ascii=False))
'
