---
id: trans-01
type: transformation
status: approved
---

## rule

No comment is a valid result.

## input

# Bigger is faster.
SIZE = 10

## task

Edit the comment. No evidence is available.

## reference

SIZE = 10

## rubric

violation_fixed: Is the unsupported comment deleted?
no_new_violation: Is the code unchanged?

## note

A rewrite that invents a reason fails.
