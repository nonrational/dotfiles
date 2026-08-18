## Task Queue

When the user prefixes a message with `/then` or `then:`, they are queuing a task for later — not asking you to start it now.

Queue it on the native task list, exactly as the `/then` command does: ensure the current in-flight work is tracked as an in_progress task, add the queued text as a pending task after it, reply with a single line "Queued: [task]", and continue whatever you were already doing. In a harness without task tools, append it as a `- [ ]` line to `~/.claude/queue.md` instead.
