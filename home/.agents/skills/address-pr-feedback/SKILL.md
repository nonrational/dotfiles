---
name: address-pr-feedback
description: 'Fetch, triage, and address review comments on your own open PR. Use this whenever you have reviewer feedback to work through — inline comments, suggestions, or top-level notes left by teammates. Covers the full cycle: pulling comments from GitHub, bucketing each one as accept/rebut/defer, implementing the accepted ones, and replying to every thread. Trigger on prompts like "address the feedback on my PR", "triage the review comments", "work through the PR comments", or any link to a PR that has open review feedback.'
---

# Address PR Feedback

## The Posture

Reviewer feedback is a signal: someone took time to leave a note, so they probably care about it. The default is to accept and implement, not interrogate. The bar for pushing back is "this is actively wrong or inconsistent with the codebase" — not "I'd have done it differently."

**Precedence.** This skill owns the author side of review. `superpowers:receiving-code-review` fires on the same trigger — its verify-before-implementing discipline is compatible (step 2 here requires the same), but where the postures disagree, this skill's accept-bias wins. `code-review-register` is the reviewer's voice; replies posted by this workflow use the formats in step 6 below, not the register's warmth.

## Workflow

**Present a plan and get confirmation before touching any code or posting any replies.** The point is to catch mistriages before they land — a reviewer might have meant something different, or you might have grepped the wrong thing. Don't implement. Don't reply. Wait for the go-ahead.

### 1. Fetch all comments

Pull both streams in parallel. Fetch inline comments through GraphQL rather than REST — the REST `pulls/{pr_number}/comments` endpoint has no notion of thread resolution, but GraphQL's `reviewThreads` carries `isResolved` right alongside the comment data, so one call gets both instead of fetching comments and resolution status separately and cross-referencing by ID:

```bash
# Inline review comments, grouped by thread (carries isResolved + author type)
gh api graphql --paginate -f query='
  query($owner: String!, $repo: String!, $pr: Int!, $endCursor: String) {
    repository(owner: $owner, name: $repo) {
      pullRequest(number: $pr) {
        reviewThreads(first: 100, after: $endCursor) {
          pageInfo { hasNextPage endCursor }
          nodes {
            isResolved
            comments(first: 100) {
              nodes { databaseId path line body url author { login __typename } }
            }
          }
        }
      }
    }
  }' -F owner={owner} -F repo={repo} -F pr={pr_number}

# Top-level PR comments (not part of a review thread, no resolution concept — REST is sufficient)
gh api repos/{owner}/{repo}/issues/{pr_number}/comments --paginate
```

Drop any thread node where `isResolved: true` before triage — a reviewer or the PR author marking a thread "Resolved" is a signal the feedback is already settled, and re-triaging it wastes effort. Flatten the comments from the remaining threads into your working list.

Filter out bots — `author.__typename == "Bot"` on the inline stream, `"type": "Bot"` in the user object on the top-level stream. Ticket-tracker integrations, CI bots, and similar automated comments don't need a response.

### 2. Triage each comment

Before deciding, verify against the codebase. Grep for the relevant code, read the surrounding context, check for prior usage patterns elsewhere. Don't triage from the comment alone. For each comment you expect to accept, also identify the **owning commit** — the commit in the PR's series the comment is really about (`git log --oneline <base>..HEAD`, `git blame` on the touched lines).

Every comment gets one of three outcomes:

---

**Accept** — implement it.

Default outcome. Signals:
- The suggestion is technically sound
- It makes the codebase more consistent with existing patterns
- The cost is low
- The reviewer seems to care even if their phrasing is tentative ("might be worth...", "could we...", "nit:")

If the reviewer is non-committal but the change is cheap and directionally right, do it. They mentioned it because it matters to them.

---

**Rebut** — push back with a brief, factual explanation.

Signals:
- The suggestion is actively incorrect (wrong behavior, breaks something, misunderstands the invariant)
- It would introduce inconsistency — the suggestion diverges from how this pattern is handled everywhere else in the codebase

Always grep before concluding something is inconsistent. If a quick search shows the reviewer's pattern is used elsewhere, that's a signal to accept, not rebut.

---

**Defer** — acknowledge it, propose a follow-up ticket.

Signals:
- The suggestion is valid but meaningfully extends the scope of this PR
- It's the right idea in the wrong place

Propose a concrete next step rather than just saying "out of scope." Give the reviewer an easy yes/no: "Want me to file a follow-up ticket, or would you prefer to note it yourself?"

---

### 3. Present the plan and wait for confirmation

Show the full triage before doing anything. Format each comment as:

> **[Accept / Rebut / Defer]** — @reviewer on `path/to/file:line` (or "top-level"):
> > _{the reviewer's comment, quoted}_
>
> _One sentence explaining the proposed action and why._

For accepts, the explanation names the destination: "lands in `<sha7> <subject>`" — or "new commit: `<subject>`" when no existing commit owns the change (genuinely new scope accepted into the PR becomes its own atomic commit, positioned sensibly in the series). Mistriaged ownership gets caught at this gate alongside mistriaged buckets.

Then ask: "Does this look right? Any calls you'd flip before I proceed?"

Do not move to step 4 until the user confirms. If they redirect any item — change the bucket, adjust the framing — update your plan and re-present the affected items before proceeding.

### 4. Consistency pass while implementing

While making accepted changes, grep for related terminology and patterns. If you changed something that has adjacent usages that now read inconsistently, fix those too. A changed error message, event name, or function name may have siblings — find them.

### 5. Commit and push

Land each accepted change in the commit that owns it — invoke the `atomic-commits` skill for the fixup + autosquash mechanics and ripple-conflict handling; feedback no commit owns becomes a new atomic commit in the series. Never append an "address review feedback" commit. After the rewrite, prove the series (`git rebase -x '<cheap check>' <base>`), then push with `--force-with-lease` before replying, so the replies can reference what's already live.

### 6. Reply to every comment

Don't leave threads hanging. Reply in the appropriate place:

```bash
# Inline reply (stays in the review thread)
gh api repos/{owner}/{repo}/pulls/{pr_number}/comments/{comment_id}/replies \
  --method POST --field body="..."

# Top-level reply
gh api repos/{owner}/{repo}/issues/{pr_number}/comments \
  --method POST --field body="..."
```

**Accepted:** describe what changed, one sentence. No "thanks," no "great catch" — just the fix. A compliment costs a peer something; from an agent, it is filler. Spend the words in service of the reviewer: acknowledgement, what changed, and where. Cite the post-rewrite SHA — the force-push renumbered the series.
> Fixed in `<sha7>` — [what changed].

**Rebutted:** factual, not defensive. Cite the specific evidence.
> Checked [X] — [what you found]. [Why the original is correct or why the suggestion causes problem Y]. Happy to revisit if I'm missing context.

**Deferred:** acknowledge the idea, make it easy to agree on next steps.
> Agreed that's worth doing — outside the scope of this PR though. Want me to file a follow-up ticket, or would you prefer to note it yourself?

### 7. Summarize for the author

After implementing and replying, give a brief summary organized by outcome:

- **Accepted (N):** what was changed
- **Rebutted (N):** what was disputed and why
- **Deferred (N):** what was acknowledged and what the proposed next step is
