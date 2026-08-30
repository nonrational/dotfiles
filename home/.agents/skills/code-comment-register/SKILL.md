---
name: code-comment-register
description: Rules for writing inline source code comments. Use when writing, reviewing, or editing comments inside source files — not PR/review comments (see code-review-register).
---

# Code Comment Register

Applies to inline source code comments. For PR and review comments, see `code-review-register`.

## The rule

Comments describe **why**, not what. The code already shows what it does.

A comment earns its place when it names a constraint, tradeoff, or invariant that the code cannot show on its own.

No comment is a valid result. Do not invent a rationale because a value or
branch looks as though it ought to have one.

## The constraint test

Before keeping or writing a comment, ask: does this name a specific constraint?

Constraints look like:

- A resource budget: "assuming a 4 GB pod", "under the 100ms SLA", "fits in one DB page"
- An observed failure: "without this guard, the retry loop opens N connections per call"
- A subtle invariant: "order matters — the validator mutates shared state"
- An external requirement: "purge within 30 days per data-retention policy"
- A deliberate tradeoff: "more memory for less CPU; tuned for write-heavy workloads"
- A platform behavior that would surprise a reader who knows the language: "`:binary.part/3` returns a sub-binary — no copy"

If there is no constraint, there is no comment.

## The failure mode

Comments can *look* like why-comments while still being what-comments. The tell
is performance or memory vocabulary used without a budget, machine spec, or
observed failure:

~~~elixir
# Bad: describes mechanics, sounds technical, explains nothing about the decision
# `drain_batch/1` materializes each upstream element before dispatching it.
# Feeding it 400-item batches bounds allocations per worker.
@batch_size 400

# Good: names the constraint and states the tradeoff
# 400-item batches on a 2 GB worker. Smaller batches cap memory but waste
# scheduling overhead. Larger ones risk OOM under backpressure.
@batch_size 400
~~~

The bad version cannot answer *why 400 and not 200 or 1600*. The good version can.

Sometimes the evidence supports the bound but not the exact number. Say that
honestly. A comment may document a hidden second role without claiming the
value is tuned:

~~~elixir
# One batch of records and results is the most held in memory at once.
# Buffering the whole input exhausted the worker on large datasets.
@insert_batch_size 400
~~~

This earns its place because the code does not show that the insert size is
also the memory window, and the observed failure explains why the window must
stay bounded. It does not pretend that 400 is optimal.

A surprising runtime guarantee is also evidence when the implementation relies
on it. It does not need a separate budget:

~~~elixir
# `binary_part/3` returns a view, so this slice does not copy the source.
binary_part(contents, offset, length)
~~~

The no-copy guarantee explains why this operation is safe for the intended
memory behavior. A comment about unrelated runtime trivia would still fail.

When the evidence does not explain the value, remove the comment instead of
padding it with a generic tradeoff:

~~~elixir
# Bad: true of almost every chunk size, but not a reason for this one
# Larger chunks use more memory. Smaller chunks use more CPU.
@chunk_size 192_000

# Better: leave the value uncommented until there is a real constraint to name
@chunk_size 192_000
~~~

## What-then-why trap

A comment that opens with what the code does before landing on a constraint is still a what-comment. Drop the mechanical lead-in and open with the constraint.

~~~elixir
# Bad: opens with what, buries the why
# `Enum.take/2` forces the header through the parser eagerly, so a malformed
# header raises before any rows are committed.

# Good: opens with the constraint
# Malformed headers must raise before any rows commit — no summary to report
# yet, and the rescue clause only covers the lazy write loop that follows.
~~~

A short orienting sentence is allowed when it names a semantic role that the
syntax cannot show, such as a sentinel row or an audit copy. It must sit beside
the relevant operation and lead directly to the reason:

~~~elixir
Enum.reduce(indexed_rows, summary, fn
  # The sentinel row is not written. Its synthetic result preserves the source
  # row number so an operator can find the cutoff.
  {_row, index}, acc when index > @row_limit ->
    add_limit_result(acc, index)
end)
~~~

This is not permission to narrate ordinary expressions.

## Rewrite trap

When editing a comment for "clarity" or "precision", do not replace plain-English constraint reasoning with mechanical description. Mechanical precision is not explanation.

Diagnostic: if you can delete the comment, rename the identifier, and lose nothing about *the decision*, the comment was not earning its place.

## Put the reason beside the decision

Do not stack several explanations above a function and make the reader map each
sentence to the body. When different lines earn their place for different
reasons, put a short comment beside each line. Keep a function-level comment
only when one invariant governs the whole function.

This also keeps comments honest: a local explanation has to justify the
operation it sits beside.

~~~elixir
# Bad: the reader has to map three reasons to three distant operations
# Parse failures must happen before writes. Validation and the write path must share
# line handling. The first row over the cap is needed to report truncation.
defp validate(rows) do
  rows
  |> line_stream()
  |> parse_rows()
  |> Stream.drop(1)
  |> Stream.take(@row_limit + 1)
  |> Stream.run()
end

# Good: each reason sits beside the operation it protects
defp validate(rows) do
  rows
  |> line_stream()
  # Validation and the write path must share line handling. Otherwise validation can
  # pass and the write path can fail after inserts begin.
  |> parse_rows()
  |> Stream.drop(1)
  # The first row over the cap is required to report truncation, and it must
  # validate before any writes.
  |> Stream.take(@row_limit + 1)
  # Force the lazy parser before writes. A malformed row must not arrive after
  # the first batch commits.
  |> Stream.run()
end
~~~

## Match the scope of the claim

Do not describe a bounded guarantee as a universal one. The comment should be
no stronger than the code:

~~~elixir
# Bad: the cap means this is not the whole file
# Validates the full file before writing.

# Good: says exactly what is covered
# Validates every row the capped restore can consume before writing.
~~~

## What to cut

- Restates what the function or variable name already says.
- Describes internal mechanics without naming a constraint.
- Would make equal sense in library documentation as in this specific codebase.
- A TODO/FIXME with no ticket reference and no condition that resolves it.
- A generic tradeoff offered without evidence for the chosen value.
- A test comment that repeats the test name.

## What to keep

- The constraint behind this value over adjacent alternatives.
- A hidden second role of a value, when tied to a concrete constraint.
- A known failure mode you worked around, with enough detail to recognize it later.
- An invariant the type system cannot enforce ("must be called after X initializes").
- Anything that would genuinely surprise a reader who knows the language and library.

## Test comments

Test comments follow different rules. The question is not "why did you make this choice?" but "why does this case exist?" A test comment earns its place when it names:

- The invariant being exercised ("proves `Stream.with_index` keeps counting across the chunk boundary")
- Why this fixture and not an adjacent one ("sized so the character's first byte lands 1 byte before the boundary")
- A known failure the test guards against ("the eager path OOM-killed the worker at 9x the input size")
- A measurement caveat that could produce a false negative ("`:erlang.memory(:total)` is VM-wide — a large concurrent allocation can eat into the margin")

Cut test comments that just describe the test setup in prose when the test body already shows it clearly.

Naming an invariant is not enough when the test title already names the same
invariant:

~~~elixir
# Bad: repeats the title instead of adding a reason for the case
# The streaming parser must match the string parser.
test "streaming parser matches string parser" do
  assert via_stream(input()) == via_string(input())
end
~~~

Split comments by the code they explain. Put the known regression above the
test; put fixture accounting and measurement caveats beside the assertion:

~~~elixir
# An 11x parser footprint exhausted the worker on large inputs.
test "keeps parser overhead below the file-size budget" do
  payload = large_input()
  {result, peak} = measure_peak(fn -> parse(payload) end)

  assert result == :ok

  # `payload` was allocated before the baseline, so `peak` is parser overhead only.
  # Runtime-wide sampling may include unrelated allocations.
  assert peak < byte_size(payload) / 3
end
~~~

## Lint

Fail a comment if any is true:

- Describes what a function or expression does without naming a constraint.
- Uses performance or memory vocabulary without a budget, machine spec, observed failure, or runtime guarantee the implementation relies on.
- Removing it and renaming the identifier covers the same ground.
- Names how the code works rather than why this approach was chosen.
- Sits above a whole function when it explains one pipe stage or branch.
- Claims a broader guarantee than the code enforces.
- Repeats a test name instead of explaining why the case or fixture exists.
