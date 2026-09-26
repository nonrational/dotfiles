---
id: disc-01
type: discrimination
status: approved
source_commit: 5aae06b
correct: after
expected_rule: Hedges of precision stay. Hedges of cowardice go.
---

Which variant is on-register, and which SKILL.md rule decides it?

## rule

Hedges of precision stay. Hedges of cowardice go. Keep: "roughly $165,000"

## before

Recently, the creator of Bun burned through roughly $200,000 worth of tokens to rewrite their core runtime from Zig into Rust. The migration was completed in mere weeks, with 99% of the commits authored by a pre-release AI model.

## after

Recently, the creator of Bun burned through roughly $165,000 in tokens to rewrite their core runtime from Zig into Rust. The migration was completed in 11 days, with a pre-release version of Claude Fable 5 authoring nearly all of the 6,778 commits.

## note

Vague, unsourced approximations ('mere weeks', '99% of the commits') are replaced with exact, sourced figures. Fixture edit: the source commit (5aae06b) reads 'in just 11 days', a modifier SKILL.md bans outright ('"Just" is banned as a modifier'); upstream purges it in c26cd1a. The 'just' is removed from 'after' here, by hand and not re-pulled from source, because a keyed CI run picked 'before' on exactly that ground and the skill supports it, which left two defensible answers under a hard gate. trans-01's reference_after and disc-08's 'direct' keep the source wording.
