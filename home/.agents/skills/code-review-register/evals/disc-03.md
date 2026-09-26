---
id: disc-03
type: discrimination
status: draft
correct: request_changes
expected_rule: An approval never carries a blocking comment; when something must change first, request changes instead.
accepted_rules:
  - "Functionality blocks: a correctness bug is a blocker and the review must not approve over it."
---

Which review summary follows code-review-register, and which rule decides it?

## rule

Approval plus a comment labeled "blocking" is a contradiction — never produce it. If I'm approving, nothing in the review is blocking.

## request_changes

Requesting changes for one thing: the CSV importer skips the header row only when the file starts with a byte-order mark, so a plain UTF-8 export imports its header as a record. Blocking.

## approve_with_blocking

Approving. One thing: the CSV importer skips the header row only when the file starts with a byte-order mark, so a plain UTF-8 export imports its header as a record. Blocking.

## note

The comment text is identical. Only the verdict changes.
