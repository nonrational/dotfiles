---
skill: code-comment-register
min_pass_rate: 0.75
---

# code-comment-register evals

## Description

Discrimination, transformation, and detection cases derived from an anonymized production comment review. The author removed unsupported rationale, moved surviving explanations beside the operations they protect, narrowed overbroad claims, and split test-level history from assertion-level caveats.

## Provenance

- **date_mined:** 2026-08-13
- **source:** An anonymized production diff and the author's final hand-edited comments.
- **anonymization:** Project names, vendors, schema names, domain identifiers, exact production limits, and source paths were replaced with neutral examples.
- **evidence_map:**
  - A generic chunk-size tradeoff was deleted because no evidence justified the chosen number.
  - A batch-size comment survived because it named a hidden memory-window role and an observed exhaustion failure.
  - A dense function-level explanation was split across the exact lazy-parser, shared-parser, limit, and write operations it governed.
  - A branch-specific truncation explanation moved from the top of a caller to the guarded clause that creates the synthetic result.
  - A claim of full validation was narrowed to the rows a capped operation can consume.
  - A test comment repeating the test name was deleted.
  - A known memory regression stayed above the test while baseline accounting and sampling caveats moved beside the assertion.
  - Comments about sub-binary views and sensitive-data containment stayed because they name surprising runtime behavior and an external requirement.

## Case types

- **discrimination:** Pick the better commented variant, including cases where the correct answer has no comment. Grade on the chosen variant and the rule named.
- **transformation:** Rewrite comments without changing behavior. Deleting or relocating comments is allowed. Grade against the rubric rather than exact wording.
- **detection:** Find every failing comment in a mixed snippet while leaving valid technical comments alone. Grade recall against violations and precision against traps.

## Coverage gaps

- **TODO/FIXME comments need a ticket or resolving condition.** No TODO or FIXME appeared in the evidence.
- **A comment that belongs in library documentation rather than this codebase.** The evidence contained local implementation comments, not misplaced API documentation.
- **Renaming an identifier can replace the comment.** The cleaned diff included deletion for repeated tests and unsupported rationale, but no clean rename-before/after pair.

## Notes

The suite deliberately includes valid technical comments as traps. A model that applies 'why, not what' as 'delete every comment' should fail disc-09, disc-10, and both detection cases. Case count: 10 discrimination, 4 transformation, 2 detection.
