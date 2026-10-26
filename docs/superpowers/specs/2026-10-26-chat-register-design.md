# chat-register design

## Problem

`language.md` covers written communication in general, `code-review-register` covers PR comments, and `prose-register` covers essays. Nothing covers a reply in a chat thread (a workplace chat tool) or a short email answering a colleague. In that medium the draft I get from an agent is a memo: it opens with ceremony, answers everything at once, and asserts what it should ask. My hand edits to such drafts show the same corrections each time.

## Evidence

One session produced a long, correct review of a script a colleague shared, and a first draft reply. I rewrote it by hand and sent it as three short messages. The edits are the key; the draft is the loser. The patterns below come from the diff between the two, plus corrections I gave in the session. The sent version outranks any rule I would infer from the draft, as in `mining-review-into-register`.

The source scenario is private. Cases use invented domains (a log-rotation script, a deploy tool, a spreadsheet export). Nothing from the source appears in the skill, its cases, or its commits.

## Rules the skill carries

1. **Open with the observation and a question, in one message.** `X isn't filtered out. Is that an oversight?` beats a thanks, a method summary, then the finding. Evidence follows the question.
2. **One topic per message.** Several topics get a count up front ("Two things:") that matches the list, then one message each, so the recipient can answer each separately.
3. **Ask rather than assert, about their work and intent.** "Is that intentional?", "Is it covered another way?" Hedge claims about their setup ("As I understand it"). State your own measurements flat: what you ran and saw needs no hedge.
4. **Ask about their plan; offer, don't assign.** "Do you plan to X in the final version?" and "I can handle that on my side" in place of "can you fix this".
5. **Say the expected outcome beside ambiguous verbs.** "Pass", "verify" and "trust" read as good news. Write which result was expected and which one happened: "the filtered bundle still trusts 7 of 14 bad chains; I expected 0."
6. **Define jargon at first use; link a source the reader may not have.** A coined label ("the second path") needs its meaning before its first use.
7. **Concrete nouns.** Name the tools, files and commands. Identifiers in backticks; longer code in a fenced block. Pasted backticks may stay literal in some composers (inferred from one screenshot), so keep the draft readable with them visible.
8. **Reply with the next turn only.** The chat continues. Answer what was asked, hold the rest in reserve for a later turn, and do not enumerate every finding.
9. **Side information goes last, marked optional.** "FWIW, ..." in its own message.

## Open decisions (defaults in bold)

- Scope: **chat and short email replies to colleagues**, or chat only. Default extends `language.md` and is listed in its scoped-registers sentence.
- Whether a finding that makes the shared artifact unsafe to run goes first even when it was not asked about. **Yes, lead with it in one line; hold the rest.** Not evidenced in the source (the unsafe finding was held in reserve by choice), so confirm before writing it as a rule.
- Cases use an invented domain. **Yes.**

## Out of scope

- Rewriting `language.md` rules. The skill extends them and wins where it applies.
- A hook or automation that detects chat drafts. The skill triggers by description.
- Chat-tool formatting beyond rule 7.

## Coverage gaps to record in the suite README

- Rule 7's backtick behavior rests on one screenshot.
- Rule 8 needs a thread, so a synthetic case must state the earlier turns; cases that omit them test length, not scope.
- No real chat threads were mined; every case is synthetic.
