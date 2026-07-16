# The nine lenses

Sweep every lens on each pass. Each is written as **Smell** (what you see) · **Ask** (the diagnostic question) · **Fix** (the pattern) · **e.g.** (a concrete case). The lenses are roughly ordered by how much a violation costs the user's reading — the top ones bury the answer, the bottom ones erode trust and inclusion.

## 1. Answer-first hierarchy

- **Smell:** The decision/answer renders at the same weight as — or less than — the evidence or metadata around it. The eye lands on the biggest, most colorful thing, and that thing is evidence, not the answer. The page opens with telemetry or aggregate stats.
- **Ask:** If the user could see only one line, is it the answer? What does the eye hit first, and is that the decision?
- **Fix:** Give the decision the most visual weight — size, weight, color, position. Demote identity and metadata to a muted footnote. Push telemetry below the fold; never open a page with stats read once and never again.
- **e.g.:** A build card where the pass/fail verdict — the one thing the user opened it for — rendered in the same small grey as the commit hash, while a large timing chart drew the eye. Promote the verdict to a bold foreground line; demote the metadata.

## 2. Signal survives collapse

- **Smell:** A collapsed row or summary state hides the one fact the user triages on, forcing an expand on every item to decide. Two meaningfully different items collapse to identical-looking lines.
- **Ask:** Can the user triage from the collapsed state alone? Do two different items look different when collapsed?
- **Fix:** Surface the delta/status in the header or summary row. If a computed signal only renders when expanded, hoist it. Summarize repetitive detail (a dozen near-identical rows → one summary line) and auto-expand only when the summary would hide real variation.
- **e.g.:** In a pull-request list, a green-checks PR and one with failing checks collapsed to identical rows — the check status only showed on expand. Put a pass/fail glyph in the collapsed row; a long list then triages without a single expand.

## 3. Redundancy inventory

- **Smell:** The same fact appears many times on one screen — name ×2, a date ×3, a status ×2. Page-global facts (a billing cycle, a legend) repeat on every card.
- **Ask:** How many times does each fact appear? Which repetitions carry no new information?
- **Fix:** Inventory every fact and its count. Each appears once. State page-global facts once near the title, not per item.
- **e.g.:** One invoice card showed the due date three times and the customer name twice, and every card restated the account's billing cycle. Cut each to one; state the billing cycle once under the page title.

## 4. One taxonomy per visual form

- **Smell:** Elements that share a shape answer different questions — a "kind" chip, a "state" chip and a "delta" chip all wear the same pill costume. A semantic color (green = healthy) gets spent on a neutral fact (green = "new"). Casing drifts between labels.
- **Ask:** Do two things that look alike mean alike? Is each color reserved for exactly one meaning?
- **Fix:** One visual form = one question. Give distinct categories distinct treatments (outline vs fill, a glyph). Reserve each semantic token for its single meaning. Pick one casing family and hold it.
- **e.g.:** A "draft" state chip and a "new" category tag wore the same green pill, so green stopped meaning "ready". Give the category a neutral outline; reserve fill-green for state alone.

## 5. One format per concept

- **Smell:** Two date formats on one card (MM-DD next to DD-MMM). A number whose meaning is ambiguous — is `0` "empty" or "full"? Locale-wrong formatting (US dates in a UK product).
- **Ask:** Is there exactly one format per concept? Would a stranger read this number the way you intend?
- **Fix:** One canonical, locale-correct format per data type. Label or caption ambiguous numbers so the reader knows which direction is good.
- **e.g.:** A booking table showed a bare amber `0` that read as an error when it meant "fully booked — none left." Caption the column ("seats remaining") and the `0` stops reading as a bug.

## 6. No engine-speak leaks

- **Smell:** Internal representation reaches the screen — raw ISO timestamps, database ids, enum names, model-internal jargon, redundant qualifiers ("Status: ACTIVE (active)").
- **Ask:** Would the user recognize every word and format here, or is this the system talking to itself?
- **Fix:** Translate at the view boundary — format dates, resolve ids to names, map enums to plain language, drop qualifiers the user never asked for. Better: have the server return structured data (`{cap, date}`) and let the client compose the sentence, so no code has to string-sniff.
- **e.g.:** A detail line read "blocked: RATE_LIMIT until 2026-10-09T00:00:00Z" two lines below a nicely formatted date. Format it inline, or pass the parts and compose "rate limit clears 9 Oct".

## 7. Affordance honesty

- **Smell:** A link that mutates state (looks like navigation, actually writes). The dominant action undersized; a destructive action sitting equal-and-adjacent to the primary one. A shared legend repeated under every item.
- **Ask:** Does each control look like what it does? Is the most common action the easiest to hit? Is the destructive one easy to hit by accident?
- **Fix:** Links navigate, buttons act. Size the primary action up, demote secondary ones to ghost, separate destructive actions from the primary. State shared legends once.
- **e.g.:** "Suggested tags" were styled as links, but clicking one wrote it to the record. Make them buttons — the chrome should tell the truth about the behavior.

## 8. Terminal states bridge forward

- **Smell:** Emptying the queue or finishing the task drops the user into silence with no next step. Empty states say "nothing here" without saying what to do.
- **Ask:** When the user finishes, or the list is empty, does the screen name the next action?
- **Fix:** Every terminal state points forward: "All reviewed — 3 approved, publish now →". Bridge to the actual next step in the workflow, don't just go quiet.
- **e.g.:** Emptying the review queue left a blank page. Add "All reviewed — 3 approved · publish now →" linking the next step.

## 9. Inclusive by construction

- **Smell:** Meaning carried by color alone (a bare colored dot whose meaning lives only in a hover title). Hard-coded palette shades instead of semantic tokens.
- **Ask:** Does this survive color-blindness and a theme switch? Is color ever the *only* signal?
- **Fix:** Pair color with a glyph and a label — never color alone. Prefer numbers and labels over color for data. Use semantic design tokens, not raw shades, so themes and brand retunes propagate for free.
- **e.g.:** A bare amber ● meant "sync pending," legible only on hover. Pair it with a label or chip, and keep the token semantic so dark mode and theme changes just work.
