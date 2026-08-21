# Getting started

**forge** is a Claude Code plugin. It takes one task through a **single cycle of the loop** — grill the plan (①), execute it (②), leave what you learned in the docs (③), and seal it to close the loop (④).

This site is forge's **English documentation**. The introduction and the skill-catalog summary live on the [landing page](https://gyuha.com/forge/), and the original Markdown and source live in the [GitHub repo](https://github.com/gyuha/forge).

## Install

Two lines in Claude Code and you're done — no DB, no server, no build.

```
/plugin marketplace add gyuha/forge
/plugin install forge@forge
```

The install pulls the repo's GitHub default branch (`main`). To install from a local path instead, put the path to the repo where `gyuha/forge` goes.

## One turn of the loop

Twenty-two skills look like a lot, but day to day you drive with **three**.

```
/fg-ask   →   /fg-run   →   /fg-next
 (plan)       (execute)     (auto-continue: verify → retro/seal)
```

- **`/fg-ask`** — start *every* task here. It grills the plan with you, one question at a time.
- **`/fg-run`** — runs the plan as a Dynamic Workflow.
- **`/fg-next`** — does the *one next step* for you (verify → retro or seal). Run it again to keep moving.

To plan once and let it drive to the end, call `/fg-next all` after `/fg-ask` — it keeps executing, verifying, and sealing until it hits a wall where it needs you.

When you lose track: **`/fg-status`** just *shows* how far you got; **`/fg-next`** just *does* the next thing. For how to use a skill, **`/fg-help`**; to check whether the state is healthy, **`/fg-doctor`**.

## Where to start reading

| What you want to know | Doc |
| --- | --- |
| What each skill does and what it takes in and puts out | [Skill detail](./skills.md) |
| How the `.forge/` files flow and what gates them | [State contract and directories](./state-contract.md) |
| How forge differs from other harnesses | [forge vs loop engineering](./forge-vs-loop-engineering.md) |
| How forge state is isolated and integrated when you use branches | [git workflow](./git-workflow.md) |
| The flow when several people work together | [Team workflow](./team-workflow.md) |
| How to handle foggy work whose decisions aren't settled yet | [fg-agenda usage guide](./agenda.md) |

## The two pillars

Break either of these while changing forge and forge stops being forge.

1. **Grilling is never put inside a Dynamic Workflow.** A workflow cannot take user input mid-run. Question-by-question grilling must happen as a conversation outside the workflow.
2. **Docs are the loop's fuel, not its by-product.** Terms sharpened in planning become the standard for execution, and retro learnings become the starting point of the next plan.
