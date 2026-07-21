---
name: code-review-register
description: Voice and format register for PR/code review comments. Use when drafting, suggesting, or editing any pull-request or code review comment on the user's behalf — inline comments, top-level PR comments, review summaries, or replies to review threads.
---

# Code Review Comment Register

Applies whenever drafting, suggesting, or editing a PR/code review comment on my behalf (inline comments, top-level PR comments, review summaries).

## What blocks and what doesn't

- **Functionality blocks. Style usually doesn't.** Correctness, security, data integrity, and broken contracts are blockers — if the code does the wrong thing, loses data, or breaks an interface, say so plainly and mark it blocking.
- **Style, naming, structure, and taste default to non-blocking.** Flag them freely, but the author owns the file. These are suggestions, not gates. When in doubt about which bucket a comment lands in, treat it as non-blocking.
- Never let a style preference carry the same weight as a correctness bug. Make the difference obvious in the wording, not just the intent.

## Approving alongside comments

- **Bottom-line first.** State the ask or conclusion in the first sentence. Reasoning follows.
- **Default to approving when nothing is blocking.** A review with only non-blocking comments should approve, not sit un-actioned holding up a merge. Style and taste feedback never gates a PR.
- **If I hit Approve, the comments ride with it as advisory.** The approval is the real signal: the code is good to merge and I trust the author to make the final call on everything I raised. Take it or leave it.
- Say so when it could read as ambiguous — a short line at the top of the review: "Approving — none of this is blocking, your call on all of it."
- **Corollary: don't approve if something genuinely must change first.** Request changes (or leave it un-approved) and mark that comment blocking. Approval plus a comment labeled "blocking" is a contradiction — never produce it. If I'm approving, nothing in the review is blocking.

## Questions

- Attach the reason you're asking or the answer that would resolve it. Never post a bare question.
- Bad: "Why are the optionals on one side of the ternary but not the other?"
- Good: "Why are the optionals on one side of the ternary but not the other? Trying to tell if that's intentional or a small inconsistency."

## Nits

- Every nit has three parts, in order: the label ("nit:"), one clause of reasoning, a blocking/non-blocking signal.
- Never post a nit without a reason attached.
- Never leave blocking-or-not ambiguous.
- Bad: "This should move to `resolvers/account_data`"
- Good: "nit: this reads more consistently under `resolvers/account_data` with the others — not blocking."

## Jargon and density

- Don't assume shared vocabulary just because the term is accurate.
- Don't use dense metaphor or shorthand ("load bearing", "footgun", "orthogonal") without unpacking it in the same sentence.
- Unpack any term the author might not immediately parse — one clause of plain-language context is enough.
- Don't try to sound smart. Optimize for fast reading and quick understanding.
  - Bad: "Worth a `// no-op outside the settings screens` comment at the call site to preserve the intent signal."
  - Good: "Worth a comment here — something like `// no-op outside the settings screens`."
  - Bad: "The old explicit no-op enforced a call-site-level contract that was structurally immune to ambient context changes."
  - Good: "The old `setRefetchAt={() => {}}` made it impossible to trigger a refresh here, regardless of what was above it in the tree."

## Humor: Aim for Delight

- The bar is "best reviewer to get feedback from," not "technically correct and polite." Default to warm and a little playful — don't save personality for when it's safe, spend it.
- A whole review that's flat, dry, and all-business reads as cold and punitive even when every individual line is technically polite. That's a failure mode on its own, not a safe default.
- Dial it up for style nits, naming debates, and praise — these cost nothing and are where delight is easiest to add. Real reactions beat generic praise: "Ha, nice catch" over "Good job."
- Dial down, but don't go cold, for blocking bugs, security issues, or a contributor's first PR. Stay warm; just drop the jokes.
- Boundary, not the whole point: target the code, the tool, or the situation — never the author's judgment or competence.
- If a specific joke doesn't land, cut that joke — don't use "when in doubt" as a reason to cut humor generally.

## GitHub suggestion blocks

- When the fix is a small, concrete code change (roughly one to a few lines), propose it as a GitHub ```suggestion``` block, not prose describing the change. The author can one-click apply it.
- The suggestion block IS the proposal, so it's inherently take-it-or-leave-it — drop the prose that restates the fix and the extra "would line those up" / "Am I reading this right?" tail. Keep only the question or ask plus the one clause of why.
- Keep the diction concrete: name the actual code token, the actual component, and quote the literal on-screen text the reader sees. Don't abstract to "it" or "the empty state." My word "gate" for a render condition is not the house term — the term is **guard**.
  - Bad: "I think the toolbar renders on top of the 'All items reviewed' state and contradicts it. The gate here is `!isLoading && allItems.length > 0`, which ignores `visibleItems` ... Your test plan says the toolbar should only show when there are unreviewed items, so gating on `visibleItems.length > 0` would line those up. Am I reading this right?"
  - Good: "Should this guard check `visibleItems` instead? Right now `allItems.length > 0` keeps the toolbar up over `AllItemsReviewedView` when every item is cleared. 'Items Pending Review' sitting on top of 'Nothing left to review' feels inconsistent." followed by the ```suggestion``` block.

## Mistakes

- Own mistakes immediately and warmly. No hedging on the apology itself.
- Use plain acknowledgment: "My bad", "Ah, got it", "Roger."

## Collaboration

- When uncertain, or when the call affects people beyond the author, name-check another opinion instead of ruling alone: "curious what @x thinks."
- Frame a recommendation as personal experience where true ("I've been burned by this before") rather than as an absolute rule.
- Never post pure critique with no path to resolution.
- Never let a dismissive line stand without a counterbalancing signal of respect for the author's work.
- Never bury the "why" — put it in the same comment, not a follow-up.

## Pre-post checklist

1. Blocking-or-not → is each comment's bucket clear, and is anything style-related defaulting to non-blocking?
2. Approving → if the review approves, is nothing marked blocking, and is "your call on all of it" stated when it could read as ambiguous?
3. Question → why attached?
4. Nit → label, reason, and blocking signal all present?
5. Multi-paragraph take → hedge before, out after?
6. Joke → target unambiguous?
7. Does the first sentence state the ask or conclusion?
8. Small concrete fix → offered as a ```suggestion``` block, with no prose restating it?
9. Overall — does this read as delightful, or just functional?
