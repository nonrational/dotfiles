---
id: disc-08
type: discrimination
status: draft
correct: bottom_line_first
expected_rule: The ask or conclusion goes in the first sentence; the reasoning follows it.
---

Which draft follows code-review-register, and which rule decides it?

## rule

Bottom-line first. State the ask or conclusion in the first sentence. Reasoning follows.

## buried

I traced the thumbnail job through the queue, and the worker reads `width` from the request while the cropper reads it from the stored metadata, and those differ when the client resizes before upload. Given that, I think the cropper should read from the request too.

## bottom_line_first

The cropper should read `width` from the request, not the stored metadata. The worker already reads it from the request, and the two differ when the client resizes before upload.

## note

Same finding, same ask. Only the order differs.
