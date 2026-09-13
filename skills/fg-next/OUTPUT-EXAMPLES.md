# Situational output examples

This is an optional reference for skill authors reviewing output instructions.
Consult a relevant example when improving a specific skill's output; routine
skill execution does not require reading this file. The examples illustrate
conversation resumes, user-operated procedures, and long reports without
establishing mandatory templates or a new mode. In authored examples, preserve
literal commands, paths, conditions, and evidence; actual responses follow the
user's language.

The invoking skill and host still decide what to report and who acts. Keep
[HANDOFF.md](./HANDOFF.md)'s table, ordering, and below-table lists where required.
Inside an unattended drive, [DRIVE.md](./DRIVE.md) still suppresses delegated
handoffs: the driver owns the report. These examples do not create an extra
report, question, approval, or pause. [ECO.md](../fg-config/ECO.md)'s scope and the
existing Explaining forge rule remain unchanged. Generated project documents
keep their own formats.

## Resume a conversation

**Use when:** a resumed conversation or a task switch makes the current work
unclear. Recover the task and the remaining decision from the available records
or conversation, and put that context in one line. If the state is unknown, say
what is unknown rather than inventing progress or a step count.

**Do not use when:** the immediately preceding exchange already makes the state
clear. Do not repeat an unchanged status on every turn or duplicate a status
surface already visible to the user.

**Same input:** GitHub issue #20 is under review; overlapping rules have been
excluded; the scope to adopt remains undecided. Both versions report only these
facts, without choosing that scope for the user.

Before:

> We excluded the overlapping rules. The scope is still undecided. This is the
> review of GitHub issue #20.

After:

> Reviewing GitHub issue #20: overlapping rules excluded; adoption scope remains
> undecided.

Continue with the actual answer or the next relevant question; the context line
does not require an extra question. At a skill handoff, use its existing table
instead of adding another state recap.

## Explain a user-operated procedure

**Use when:** the user must perform two or more ordered actions. Number bounded
actions and keep their prerequisites attached. First establish that these are
the user's actions: do authorized, agent-runnable work yourself.

**Do not use when:** there is only one action, order does not matter, or the
agent can perform the authorized work. Do not turn comparisons into procedures,
move an existing handoff into a numbered list, or add permission questions.

**Same input:** forge has already been installed or updated in Claude Code; this
environment requires the user to start a fresh session. The user wants to check
skill availability, then inspect fg-run help. These commands are for this stated
host; adapt to the actual host instead of copying them into another environment.

Before:

> After installing or updating forge in Claude Code, start a fresh session,
> run `/forge:fg-help` to check skill availability, then run
> `/forge:fg-help fg-run` to inspect execution help.

After:

> After installing or updating forge in Claude Code:
>
> 1. Start a fresh session.
> 2. Run `/forge:fg-help` to check skill availability.
> 3. Run `/forge:fg-help fg-run` to inspect execution help.

The example does not require a restart for unrelated tasks or assume that every
host needs one. No command, prerequisite, or purpose disappears in the rewrite.

## Group a long report

**Use when:** a long list is easier to compare in meaningful groups. Put the
most consequential group first, preserving every item required by the task.
Keep each finding's severity, location, evidence, and action if supplied.

**Do not use when:** grouping adds more structure than information, the requested
format fixes the order, or an existing table already makes the comparison clear.
There is no five-item cap. Never hide audit findings, required warnings, or a
requested complete inventory behind “ask for more.” Lists required below a
handoff table remain below it.

**Same input:** a hypothetical review supplies the following six findings. The
IDs make the before/after mapping visible; they are not new forge state fields.
Both versions retain all six findings and their actions.

Before:

- F1 — Error: `config.json` is invalid JSON; correct the syntax before loading.
- F2 — Docs: `README.md` omits the setup step; add it.
- F3 — Error: `hooks/start.sh` is missing; restore the referenced hook before startup.
- F4 — Docs: `README.ko.md` omits the setup step; add the matching translation.
- F5 — Warning: `guide.md` points to missing `old.md`; replace that link.
- F6 — Warning: `help.md` points to missing `removed.md`; replace that link.

After:

**Errors — loading and startup**

- F1 — Error: `config.json` is invalid JSON; correct the syntax before loading.
- F3 — Error: `hooks/start.sh` is missing; restore the referenced hook before startup.

**Warnings — broken references**

- F5 — Warning: `guide.md` points to missing `old.md`; replace that link.
- F6 — Warning: `help.md` points to missing `removed.md`; replace that link.

**Docs — setup instructions**

- F2 — Docs: `README.md` omits the setup step; add it.
- F4 — Docs: `README.ko.md` omits the setup step; add the matching translation.

This is a presentation example, not a diagnosis of the current repository. Do
not upgrade a finding's severity or claim a fix was completed while regrouping.

## Attribution

The ideas of numbered procedures, context restoration, and grouped lists are
adapted from [ayghri/i-have-adhd](https://github.com/ayghri/i-have-adhd) (MIT).
These are forge-specific examples, not a vendored copy of that skill. They make
no assumption about the reader's diagnosis and do not activate session-wide
rules or claim a measured improvement in model output.
