# Worked example: an approval queue

A full review, start to finish, so you can see the target quality bar. The domain is generic on purpose — a reviewer works a queue of pending **access requests**, each shown as a card that proposes a decision (grant / deny / defer) with the evidence behind it. Substitute your own screen; the shape holds.

Nothing here is a real product — the point is the *structure*: a one-line diagnosis, findings ranked by parsing cost, an explicit "don't touch" list, and a three-phase split by risk. Reproduce that structure on your own screen, not these nouns.

---

## Context

Screen: `/requests/review` — the reviewer's job is **decide one access request** (grant, deny or defer) and move to the next. Reviewed against the full seed (~20 mixed requests, some matching policy, some deviating), driving the live screen and reading the `RequestCard` → `EvidenceGrid` → `DecisionBar` component path.

## Core diagnosis

**The card buries its own answer** — the proposed decision has the lowest visual weight on the card, collapsed rows hide whether the request deviates from policy, and a 30-cell evidence grid answers a yes/no question.

## Findings, ranked by parsing cost

- **F1 — The proposed decision has the lowest visual weight.** The decision line ("Grant · read-only · 90 days") renders at the same tiny muted size as the requester's employee id. The eye lands on the evidence grid — biggest, most colorful — but the grid is *evidence*, not the decision. *(Lens 1)*
- **F2 — Collapsed rows hide the policy delta.** A policy-matching request and a scope-escalating one collapse to identical lines with the same green "ready" chip, so the reviewer must expand every row to triage. The delta is already computed client-side — it only renders when expanded. *(Lens 2)*
- **F3 — The evidence grid: 30 numbers for a yes/no question.** Rows are near-identical; nothing marks the columns that matter; a post-decision "remaining quota" cell shows a bare `0` that reads as an error when it means "granted the last seat." *(Lens 2, Lens 5)*
- **F4 — Redundancy inventory (one card):** requester name ×2, "expires 20 Oct" ×3, the scope string ×2, "as requested" ×2 (inline + chip on the same line). *(Lens 3)*
- **F5 — Engine-speak in the denial reason:** raw ISO ("blocked_until: 2026-10-09") and an enum ("reason: QUOTA_EXCEEDED") two lines below a nicely formatted date. *(Lens 6)*
- **F6 — Three chip taxonomies in one pill costume.** Kind (New/Renewal), state (ready/blocked) and delta (= as requested) share a shape but answer different questions; "New" is brand-green though newness is neutral. *(Lens 4)*
- **F7 — Action affordance.** Grant / Deny / Defer are equal-size buttons; the dominant action is undersized and the destructive Deny sits adjacent at the same size. Suggested-alternate scopes are styled as links but each click writes an adjustment. The legend repeats under every card. *(Lens 7)*
- **F8 — No finish state.** Clearing the queue drops the reviewer into a blank page — no bridge to the "notify requesters" step that comes next. *(Lens 8)*

## Fine as-is (don't touch)

Queue mechanics (grouping, auto-advance, jump-to-next, sticky footer) · undo on every action · keyboard navigation · the evidence data choices themselves (what's shown is right; how it's weighted is the problem) · semantic-token discipline · the color-blind-safe glyph+label pairing already used in the status column.

## Phased plan

**Phase 1 — copy, hierarchy, CSS (no data changes).** Highest leverage; do F2 and F1 first — they change what the reviewer sees in the first second.

- Lead with the decision: promote the decision line to a larger foreground semibold; demote identity to a muted footnote. *(F1)*
- Render the delta chip in the collapsed header so a long queue triages without expanding. *(F2)*
- De-dupe pass: one name, one expiry, one scope string; drop the inline "as requested". *(F4)*
- Grant prominence: solid primary button, roomier; order Grant · Defer · Deny (ghost). *(F7)*
- Caption the evidence grid ("seats free after this grant") so `0` stops reading as an error. *(F3)*
- Format the denial reason inline; state the shared legend once under the queue header. *(F5, F7)*

**Phase 2 — structural.**

- Summary-first evidence: default to one summary row; "show detail ▸" expands; auto-expand only when rows diverge. *(F3)*
- Mark the columns that matter (the escalated scope) so the grid narrates the deviation itself. *(F3, F2)*
- Reorder the card: decision → actions → evidence → alternates → identity footnote, so Grant is never below the fold. *(F1, F7)*
- Tabular collapsed rows (rank · requester · kind · ask→decision · state) so a 20-row queue scans in columns. *(F2)*
- Alternate scopes become buttons, not links — a click writes state. *(F7)*
- Give kind a neutral outline; reserve fill-green for state. *(F6)*

**Phase 3 — new data or navigation.**

- Server returns a structured denial reason (`{kind, limit, date}`) so the client composes plain English and no code string-sniffs. *(F5)*
- Finish-line handoff: when the queue empties, the footer becomes "All decided — notify N requesters →". *(F8)*
- Blocked rows get a deep-link to the policy that blocked them. *(F5, F8)*

**Test notes:** several copy strings are pinned in the card unit tests and the queue e2e spec — update them alongside the copy changes. Compression of the collapsed label is the point, so a test pinning the old verbose label should be updated, not worked around.
