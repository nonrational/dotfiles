---
description: Queue a task for after current work — appends to ~/.claude/queue.md without interrupting
---

Append the following task to `~/.claude/queue.md` using a bash heredoc:

```bash
echo "- [ ] $ARGUMENTS" >> ~/.claude/queue.md
```

Then respond with a single line: "Queued: $ARGUMENTS" — nothing else. Do not start working on the task.
