# Claude Code は親プロセスの PATH を rc ファイルの PATH より前に置くので、mise の shims をコマンドごとに先頭へ戻す
PATH="${HOME}/.local/share/mise/shims:${PATH}"
