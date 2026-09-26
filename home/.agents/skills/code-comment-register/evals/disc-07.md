---
id: disc-07
type: discrimination
status: approved
correct: no_comment
expected_rule: Delete test comments that repeat the test name instead of explaining why the case or fixture exists.
---

Which version follows code-comment-register, and which rule decides it?

## rule

A test comment that repeats the test name.

## evidence

The final edit deleted a comment that only restated the test title.

## duplicate

```
# The streaming parser must match the string parser.
test "streaming parser matches string parser on quoted fields" do
  assert via_stream(input()) == via_string(input())
end
```

## no_comment

```
test "streaming parser matches string parser on quoted fields" do
  assert via_stream(input()) == via_string(input())
end
```

## note

The assertion and title already say everything in the comment.
