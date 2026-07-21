## macOS Interactions (Darwin only)

These instructions apply only on Darwin. On Linux, `pbcopy` does not exist — skip them.

### Clipboard

When you produce output the user is likely to paste elsewhere — GitHub (commit messages, PR/issue bodies, comments), email drafts, a browser, or any other external destination — also copy it to the clipboard with `pbcopy`. This covers markdown-formatted text (copied raw, per the markdown rules) and URLs the user will open or share.

Pipe via a quoted heredoc to preserve formatting, e.g. `cat <<'EOF' | pbcopy … EOF`.

The user runs a clipboard history tracker (Maccy), so clobbering the current clipboard is acceptable for the sake of speed — don't ask first.

Always tell the user when you've copied something to the clipboard.
