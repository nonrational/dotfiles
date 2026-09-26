---
id: trans-02
type: transformation
status: draft
---

## rule

````
When the fix is a small, concrete code change (roughly one to a few lines), propose it as a GitHub ```suggestion``` block, not prose describing the change. Keep only the question or ask plus the one clause of why.
````

## input

The header check compares against "content-type" but the incoming header map keeps the original casing, so a client sending "Content-Type" skips the JSON branch. Could you lowercase the key before the lookup?

## task

Edit this draft comment according to code-review-register. The fix is one line: replace `const type = headers["content-type"];` with `const type = getHeader(headers, "content-type");`. `getHeader` already exists in the same file and matches case-insensitively. Return only the revised comment.

## reference

````
A client sending `Content-Type` skips the JSON branch: the header map keeps the original casing and this lookup is case-sensitive.
```suggestion
const type = getHeader(headers, "content-type");
```
````

## rubric

````yaml
violation_fixed: Is the fix offered as a ```suggestion``` block containing the replacement line, rather than prose asking for the change?
placement: Does the prose carry the ask and the why in a sentence or two, with no separate sentence that spells out the code change the block already shows (for example 'could you lowercase the key')? A question that names the fix, and a blocking-or-not signal, both pass.
no_new_violation: Is the suggested line the one-line fix given in the task, with nothing else changed or added?
````

## note

The task supplies the exact line so the subject never has to invent code. The register's own example pairs a question naming the fix with the block, so that shape passes; prose that separately describes the edit, or asks the author to make it instead of offering the block, fails placement.
