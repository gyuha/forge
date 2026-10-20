---
name: fg-rules
description: Analyze a project's patterns and propose durable AI coding rules for user review; save only adopted changes under .forge/rules/ and connect project instructions for ordinary coding. Reconcile rules without overwriting manual edits. Utility outside the loop. Use for "generate project rules", "update coding rules", "프로젝트 규칙 생성", "규칙 갱신", or "fg-rules [topic]".
---

# fg-rules — reviewed project rules

An on-demand utility outside the forge loop. Turn supported project patterns into
**proposed** instructions, then persist only what the user adopts. A frequent
pattern is evidence, not permission to make it a rule.

**Language**: Write every user-facing message and generated project document in
the user's language. Keep paths and command identifiers unchanged.

**Explaining forge**: forge's vocabulary is not the user's — `verified: failed`, `unsealed tail`, a pillar or gate name means nothing unread. **Always, never gated on `eco`**: gloss a forge-specific term on first use in a message (a few words, not a paragraph), put the purpose before the mechanism, and lead with the answer, closing on what it means for the user. A gloss is not filler — with `eco` on, ECO.md's terse rules govern **form** (length, padding) while these govern **vocabulary**, so terseness never deletes a gloss.

**Host contract**: Review uses `structured_choice` when available. Read [../../core/HOST.md](../../core/HOST.md),
[../../core/INTERACTION.md](../../core/INTERACTION.md), and the active host's
interaction adapter. Review happens in this conversation, one bounded question
at a time; use `structured_choice` when available, otherwise numbered text.
No delegation or hook is required.

**Location**: `.forge/rules/` is relative to the **project root**, on every branch,
as defined in [../fg-run/FORGE-ROOT.md](../fg-run/FORGE-ROOT.md). Find the git
top-level, or use the explicitly selected project directory outside git.
Never write rules inside a branch's forge state directory or the plugin install.
Ordinary git branches/worktrees version their own files; this is not an external
shared store.

## Inspect before proposing

The optional argument is a topic, such as `testing`, `API`, or `테스트`, not an
executable command. With no topic, inspect project-specific naming, file
placement, dependency boundaries, error handling and testing as applicable.
With a topic, limit proposals and changes to that topic; do not prune other rules.

Read existing project instructions and their referenced files first, including
AGENTS.md, CLAUDE.md, applicable nested/override instructions, existing rules and
formatter/linter configuration. Preserve the existing authority and delegation
relationships. Inspect representative current source and tests, including
exceptions to each apparent pattern. Exclude generated/vendor output and secrets.

If `.forge/codebase/` exists, read only relevant map documents and check their
claims against current files. Missing or stale maps do not block analysis.
Do not invoke fg-map or change its output.

- **fg-map** describes what the implementation currently does.
- **fg-rules** proposes what future work should follow.
- **CONTEXT.md** defines domain terms; **ADRs** explain decisions.

Do not copy those documents wholesale into rules. Existing explicit instructions
take priority over inferred conventions. Mixed patterns, weak evidence, or
conflicting instructions are reported as deferred candidates, with the reason.
Do not resolve an existing instruction conflict by silently choosing a winner.
Do not propose generic best practices or duplicate constraints already enforced
by the project's formatter/linter.

## Review concrete changes

Present a compact candidate list with stable identifiers, each containing:

- operation: add, modify, or delete;
- proposed instruction and its applicability (paths or task kinds);
- concrete evidence paths and any relevant exceptions;
- conflict/deferred status and the reason, if any.

Connection repairs are standalone candidates too, even when every adopted rule
is unchanged. For example, if existing rules and their index are valid but a
new host's entrypoint does not read them, propose only the missing read
instruction as its own candidate. Review its exact patch and apply it only
when adopted; preserve the unchanged rule files and index. Do not manufacture
a rule-body change to make a connection repair eligible.

For an update, read the **current** rule text, including manual edits. Show the
actual before/after change. Absence of a pattern is not permission to delete a
rule. Existing rules are not disposable generated output.

Prepare the full proposed patch in conversation before asking for adoption:
include the rule text, index changes, project-instruction connection and any
minimal ignore exception needed for tracking. Follow
[CONNECTIONS.md](./CONNECTIONS.md) to prepare that connection. Do not create a
draft file in the project or change instructions while still proposing.

Ask which candidate IDs to adopt, with “none” as an explicit option. For a
deferred conflict, recommend retaining the existing instruction; changing it
requires an explicit choice covering both the old instruction and the new rule.
Generic “adopt all” does not resolve a conflict labeled deferred.

Recompute the index, connection and ignore edits for the **selected subset**.
For example, selecting a last-rule deletion while rejecting its proposed
replacement can require connection cleanup that the original combined patch
did not show. Present and get adoption of any such new edits before applying
that dependent change; do not ask again about edits already adopted unchanged.

If the user already approved **this exact patch** in the current conversation,
do not ask again. A request to generate/update rules alone is not adoption.
If the user changes a candidate materially, show its revised patch before
applying it. Approval of a rule never silently includes unrelated instructions.

After considering both rule and connection candidates: no candidates, none
adopted, or no actual changes → report that result and stop without creating
directories or rewriting files. Unchanged rule bodies alone are not a reason
to skip a needed connection proposal.

## Apply adopted changes

Immediately before editing, re-read affected files. If they differ from the
reviewed version, preserve the intervening edits and show a revised patch for
the affected candidates; still-applicable approved changes may proceed.

Create only the topic files needed, using stable descriptive names, for example
`.forge/rules/testing.md`. Keep adopted rule bodies in one place. Each rule
contains its instruction, applicability and evidence paths; add exceptions or
a short example only when they clarify the instruction. Use the user's language.
Do not copy credentials, sensitive values, or bulk source excerpts into rules.

Maintain `.forge/rules/INDEX.md` as a short routing index:

```md
# Project rules

Read the common rules and rules matching the current task before editing.
Existing project instructions, including more specific instructions, retain
their authority. If a rule conflicts with them, report the conflict.

| Applies when | Rule file |
| --- | --- |
| Editing tests | [Testing](testing.md) |
```

Translate this prose and headings; keep paths unchanged. Add a common-rules
entry only when there are adopted common rules. The index lists applicability
and links, not duplicate rule bodies. Preserve existing user-written index
content. If `INDEX.md` already has another purpose, propose an in-place integration
or an alternative entrypoint explicitly rather than replacing it.

Apply only the approved connection and ignore changes. Existing text outside
the adopted edits must stay intact. Reuse a working connection instead of
appending another; do not rely on generated markers as ownership of manual edits.
Topic-scoped updates may change that topic's index entry but not other entries.

Deletion needs explicit adoption too. If it removes the last rule, include
index/connection cleanup in the reviewed patch. Do not leave a dangling read
instruction, and do not remove unrelated user content to make a directory empty.
Never auto-stage, commit, push, or edit user-global configuration.

## Verify and report

Inspect the resulting diff against the adopted patch:

1. Every adopted rule is present with scope and evidence, rejected/deferred
   changes are absent, and untouched/manual content is preserved.
2. Starting at each intended host entrypoint, follow the read instructions to
   the index and applicable files. Resolve real paths from the consuming file;
   check for missing files and circular instruction chains.
3. In git projects, check actual ignore behavior for each new rules file.
   A matching exception line alone does not prove that its parent is traversable.
4. Separate **connection verified** (paths and read instruction checked) from
   **loading observed** (a fresh host session actually read the rules). Never
   describe either as guaranteed obedience. Use the host checks in CONNECTIONS.md.

If verification fails, repair within the adopted patch and check again. If it
needs a different policy or additional edits, report what is incomplete and
review that change; do not claim success.

Report adopted/deferred counts, changed paths, and the connection verification
level. Give a normal coding-task example for checking loading in a new session.
This utility does not advance the forge loop, so do not invent a next loop stage
or prompt the user to run fg-ask. An unchanged run gets a one-line report.

## Boundaries

Writes are limited to adopted `.forge/rules/` content and reviewed project
instruction/ignore edits. Do not modify source code, maps, glossary, ADRs,
plan/run/STATUS, or other loop state. Do not add hooks, runtime enforcement,
automatic re-analysis, or copies for every possible AI tool.
