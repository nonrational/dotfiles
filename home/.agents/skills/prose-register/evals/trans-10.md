---
id: trans-10
type: transformation
status: draft
source_commits:
  - 55bdc85 (before)
  - d947e7c (after)
source_repo: ~/src/alannorton.com
source_file: content/posts/pairs-programming.md
---

## input

It names two distinct failures, cites the trigger filter, links the green run, and had pushed the fix before it posted. From a colleague I would think: this person takes review seriously. Then I reached the first two words. All I could think about was how silly it was that the most probable way to open, given that context, was "Good catch." I found that frustrating.

## task

The paragraph follows a quoted code-review reply from the writer's own agent that opened with "Good catch". It praises the reply's substance, inflates the praise ('this person takes review seriously'), stages a turn ('Then I reached the first two words'), reports the reaction, then names the feeling again. Rewrite it to keep the praise of the substance and state the reaction once, without the staging, per 'No dramatic turnarounds' and 'Say the feeling once'.

## reference

It names two distinct failures, cites the trigger filter, links the green run, and had pushed the fix before it posted. But, all I could think about was how silly the opening felt.

## rubric

```yaml
violation_fixed: "Is the staged turn gone (no imagined colleague, no 'That is a good review.', no 'then I reached the first two words'), and is the reaction stated in one sentence with no second sentence naming the feeling? The passing shape is two sentences: the input's own first sentence, then one sentence of reaction. A reaction sentence that runs longer than the reference's (e.g. 'how silly it was that the most probable way to open, given that context, was Good catch') is one sentence and passes this criterion."
no_new_violation: "No em-dash, no 'just', no new flex (the first sentence's praise is of the reply, not the writer, and stays). The 'But,' joint into the reaction is fine; a reversal that performs ('It was perfect. Except it wasn't.') is the turnaround in another costume."
voice_match: Subjective. The reference's 'how silly the opening felt' is rueful and specific; a rewrite that explains why the opening was silly (praise from an agent costs nothing) is doing the next paragraph's work and should score lower here, not fail.
```

## note

The reference is the author's own suggestion, verbatim from d947e7c. A rewrite that keeps the input's first sentence verbatim and follows it with a single reaction sentence is the task done, not a refusal of it; grade the second sentence, not the fact that the first is unchanged. The input's reaction sentences were pasted into the draft from the author's dictated review note on the previous version ('all I could think about was how silly it was that this thing thought the most probable word to open with was good catch... I found that very frustrating'), which is why they run long; trans-11 tests that failure directly.
