---
id: disc-14
type: discrimination
status: approved
source_commits:
  - f3ca29e (before, hand-edited)
  - cf18538 (after)
source_repo: ~/src/alannorton.com
source_file: content/posts/mature-poets-steal.md
correct: after
expected_rule: No flex.
arguable: true
---

Which variant is on-register, and which SKILL.md rule decides it?

## rule

No flex. Never a sentence that flatters the writer. If a line's real work is showing how generous or sharp you are, cut it. Thank people rather than reporting that you did: *(Thanks for the idea!)*, not *I let them know, and thanked them for the idea!*

## before

Then it kept going. Scoping that bell meant reading my terminal config. iTerm2 keeps its settings in a binary plist: the one piece of my setup no symlink could manage and no diff could review. kitty keeps its config in a text file. I installed it alongside to see, and immediately became a convert. I let [name] know, and thanked him for the inspo!

## after

Then it kept going. Scoping that bell meant reading my terminal config. iTerm2 keeps its settings in a binary plist: the one piece of my setup no symlink could manage and no diff could review. kitty keeps its config in a text file. I installed it alongside to see, and immediately became a convert. (Thanks for the inspo, [name]!)

## note

Fixture edit (2026-09-25): f3ca29e reads 'I let [name] know immediately, and thanked him for the inspo!', repeating the previous sentence's 'immediately'; 'before' drops the repeat so the pair differs only in reporting the thanks versus giving it. Both variants reduce a markdown link ('installed it alongside') to its text and redact the friend's first name as [name]. 'after' is the author's own edit. Reporting that you thanked someone shows the writer's generosity; addressing them does the thanking, which is the example this PR adds to the No flex rule in generic form. Arguable because it is new and because a reader can defend the narrated line as the warmer one; it stays flagged until CI runs show the choice holds. Fills the 'No flex' coverage gap.
