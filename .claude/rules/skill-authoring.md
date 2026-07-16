## Authoring Portable Tooling (Skills, Agents, Commands, Hooks)

Applies whenever you create or edit a **skill, agent, command, hook, or any reusable artifact that will live outside a single project** — in `~/.claude/`, this (public) dotfiles repo, a plugin, or anywhere it will be shared or published. A skill checked into a project's own repo may reference that project; this rule is about artifacts that travel.

### The rule

**No project-specific identifiers in portable tooling.** When you synthesize a skill/agent/command from real work — a review you ran, a bug you fixed, a screen you built — keep the *structure and the lessons*, replace the *nouns*. If a reader could identify the source project, it is not generic enough.

### What counts as an identifier — scrub all of these

- Client, company or product names, and internal codenames.
- Domain nouns and jargon specific to one project — the words that only make sense inside that product.
- Named entities or instances from the data — records, environments, rooms, accounts, people by name.
- Third-party vendors or systems the project integrates with.
- Repo names, hostnames, internal URLs, ticket/issue IDs, seed-data values.

### Instead

Invent a neutral, universally-recognizable example — support tickets, invoices, pull requests, a settings table, a booking grid. Vary the domain across examples so none reads as a real product.

### Verify before you finish

Grep the artifact for the source project's identifiers before calling it done — a clean grep is the gate:

```bash
grep -rniE '<client>|<product>|<domain-noun>|<vendor>|<repo>' <artifact-dir>
```

Fill the pattern with the actual terms from the project you drew the material from.

**This rule obeys itself.** The placeholders above are deliberately fake — never drop a real client or product name into a portable artifact, not even as an "example".

### Credit what you took

When a portable artifact comes from someone else's work, record it in **frontmatter**, not prose. Frontmatter is greppable; a paragraph of credit is not.

- `source: <url>`. A verbatim copy, vendored as-is.
- `forked-from: <url>`. A derivative. You kept the skeleton and changed the rules.

```bash
grep -rnE '^(source|forked-from): https?://' .claude/skills/*/SKILL.md
```

Anchor on the URL, not the key. A bare `source:` also matches template blocks *inside* a skill's body, where the same word means something else entirely.

Name the relationship honestly. If the structure survived, it is `forked-from`, not "inspired by". Leave the original where it is; overwriting a vendored artifact in place erases the breadcrumb back to whoever wrote it.
