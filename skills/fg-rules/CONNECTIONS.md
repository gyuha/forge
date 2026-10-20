# Connecting adopted rules to ordinary work

Read this when preparing or verifying a rules patch. A file link is not an
automatic-load mechanism. Build an explicit read chain from the project's
existing host instructions to the rules index without replacing those
instructions.

## Select and preserve entrypoints

Inspect the files before choosing a connection:

- If AGENTS.md already delegates to CLAUDE.md, put the index read instruction
  in CLAUDE.md and preserve the delegation. Do not add a reverse delegation.
- If both files are independent, propose a small index read instruction in each
  intended entrypoint. Rule bodies remain only in `.forge/rules/`.
- If only one exists, connect it for the host that reads it. Propose the missing
  entrypoint only when the user's intended host needs it; do not create files
  for unused hosts.
- If neither exists, propose the active host's supported project instruction
  entrypoint. If that host's mechanism is unknown, provide an explicit manual
  read instruction and report the connection as unverified.

Check nested and override files too: a more specific instruction may supersede
or narrow a root rule. Do not rewrite nested policies merely to make a general
pattern universal. Existing project authority remains above inferred rules;
the user can explicitly adopt a change to an existing policy during review.

Use wording with an action and a path, translated into the user's language:

> Before editing, read `.forge/rules/INDEX.md` from the project root, then read
> its common rules and the topic files whose applicability matches this task.
> Existing project instructions, including more specific instructions, retain
> their authority. Report conflicts rather than silently replacing them.

For an entrypoint outside the root, state the project-root-relative path
explicitly or calculate the correct relative path. Preserve existing headings,
hand-written text, delegation and unrelated links.

## Host evidence and limits

Use official documentation or the actual host loader to establish the current
entrypoint mechanism when preparing a connection. Useful primary references:

- Codex: [AGENTS.md guide](https://learn.chatgpt.com/docs/agent-configuration/agents-md).
  Account for override files, directory scope and instruction size limits.
- Claude Code: [project memory](https://code.claude.com/docs/en/memory).
  Preserve existing CLAUDE.md imports and project-local instructions.
- For other hosts, consult their own current instructions or inspect their
  installed loader; do not infer loading from a filename another host uses.

Do not require a network request if current local loader evidence already
establishes the mechanism. If neither documentation nor runtime evidence is
available, still propose/store adopted rules, but label automatic loading
unverified and explain how to read the index manually. Do not claim that
Forge's ability to run a skill implies native instruction loading.

Verification has two levels:

1. **Connection verified**: the host entrypoint is established, the explicit
   read chain resolves to existing files, and scope/overrides are accounted for.
2. **Loading observed**: in a fresh ordinary coding session, without invoking
   fg-rules or supplying the rule body in the prompt, the host reads the index
   and applicable topic. Inspect tool/read evidence or loaded context, not just
   a coincidentally conforming answer. A session that generated the rules is
   not fresh-load evidence.

Record the host and evidence actually checked. If a fresh session cannot be
started, report level 1 only and give the user a small ordinary coding task to
try in a new session. Neither level guarantees future model compliance.

## Git tracking

Rules are project-owned persistent documents. Inspect `.gitignore`, scoped
ignore files and actual git ignore results before proposing a change. For the
usual `.forge/*` pattern, an exception for `.forge/rules/` can suffice. If
`.forge/` itself is excluded, a child exception cannot work until its parent is
traversable; propose a narrow adjustment that keeps unrelated forge state
ignored. Do not remove broad ignore policies or force-add files.

Check each proposed file with `git check-ignore` after writing; use its exit
status and diagnostic output, not a count of matching text. `git check-ignore
--no-index -v` can diagnose tracked paths as well. Honor a user's deliberate
choice to keep rules local and report that they will not travel with git.
Do not edit global excludes or `.git/info/exclude` without specific approval.
