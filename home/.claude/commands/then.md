---
description: Queue a task — ensures the session task list exists, captures current work on it, and adds the argument as the next pending task
argument-hint: "task to queue"
allowed-tools: TaskCreate, TaskUpdate, TaskList
---

Queue the following without interrupting the current work:

$ARGUMENTS

1. Run TaskList. If there is in-flight work this session and it isn't on the list, create a task for it (TaskCreate) and mark it in_progress (TaskUpdate) — the queue needs the current work as its head. If nothing is in flight, skip this step.
2. Create a pending task for the quoted text above (TaskCreate). If step 1 identified current work, block the new task on it (TaskUpdate addBlockedBy) so it is explicitly next.
3. Reply with a single line: "Queued: $ARGUMENTS".
4. If work was in flight, return to it — the queue drains only after the current work completes. If you were idle, start draining now.

The queue is a program, not a parking lot: whenever the in-flight work completes and unblocked pending tasks remain, work the list in ID order (mark in_progress, do it, mark completed) instead of ending your turn.
