---
name: comment-register
description: Rules for writing inline source code comments. Use when writing, reviewing, or editing comments inside source files — not PR/review comments (see code-review-register).
---

# Comment Register

Applies to inline source code comments. For PR and review comments, see `code-review-register`.

## The rule

Comments describe **why**, not what. The code already shows what it does.

A comment earns its place when it names a constraint, tradeoff, or invariant that the code cannot show on its own.

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

Comments can *look* like why-comments while still being what-comments. The tell is performance or memory vocabulary used without a budget or spec:

~~~elixir
# Bad: describes mechanics, sounds technical, explains nothing about the decision
# `drain_batch/1` materializes each upstream element before dispatching it.
# Feeding it 500-item batches bounds allocations per worker.
@batch_size 500

# Good: names the constraint and states the tradeoff
# 500-item batches on a 2 GB worker. Smaller batches cap memory but waste
# scheduling overhead. Larger ones risk OOM under backpressure.
@batch_size 500
~~~

The bad version cannot answer *why 500 and not 250 or 2000*. The good version can.

## What-then-why trap

A comment that opens with what the code does before landing on a constraint is still a what-comment. Drop the mechanical lead-in and open with the constraint.

~~~elixir
# Bad: opens with what, buries the why
# `Enum.take/2` forces the header through the parser eagerly, so a malformed
# header raises before any rows are committed.

# Good: opens with the constraint
# Malformed headers must raise before any rows commit — no summary to report
# yet, and the rescue clause only covers the lazy import loop that follows.
~~~

## Rewrite trap

When editing a comment for "clarity" or "precision", do not replace plain-English constraint reasoning with mechanical description. Mechanical precision is not explanation.

Diagnostic: if you can delete the comment, rename the identifier, and lose nothing about *the decision*, the comment was not earning its place.

## What to cut

- Restates what the function or variable name already says.
- Describes internal mechanics without naming a constraint.
- Would make equal sense in library documentation as in this specific codebase.
- A TODO/FIXME with no ticket reference and no condition that resolves it.

## What to keep

- The constraint behind this value over adjacent alternatives.
- A known failure mode you worked around, with enough detail to recognize it later.
- An invariant the type system cannot enforce ("must be called after X initializes").
- Anything that would genuinely surprise a reader who knows the language and library.

## Test comments

Test comments follow different rules. The question is not "why did you make this choice?" but "why does this case exist?" A test comment earns its place when it names:

- The invariant being exercised ("proves `Stream.with_index` keeps counting across the chunk boundary")
- Why this fixture and not an adjacent one ("sized so the character's first byte lands 1 byte before the boundary")
- A known failure the test guards against ("the eager path OOM-killed the worker at 13× the file size")
- A measurement caveat that could produce a false negative ("`:erlang.memory(:total)` is VM-wide — a large concurrent allocation can eat into the margin")

Cut test comments that just describe the test setup in prose when the test body already shows it clearly.

## Lint

Fail a comment if any is true:

- Describes what a function or expression does without naming a constraint.
- Uses performance or memory vocabulary without a budget or machine spec.
- Removing it and renaming the identifier covers the same ground.
- Names how the code works rather than why this approach was chosen.
