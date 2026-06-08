# Forge root resolution

> Where forge state lives depends on the current git branch. This rule is defined **once, here** (owned by fg-run, the primary state navigator); every loop skill (fg-ask, fg-run, fg-learn, fg-done, fg-status, fg-next, fg-quick) resolves the root through it before reading or writing any `.forge/...` path. Do not duplicate the logic — reference this file. (See `.forge/adr/0011-branch-isolated-forge-root.md`.)

## The rule

1. **Current branch** — `git rev-parse --abbrev-ref HEAD`.
2. **Default branch** — `defaultBranch` in `.forge/config.json`; if the file or key is absent, `main`.
3. **Resolve**:
   - current branch **==** default branch → forge root is **`.forge/`** (exactly as before this feature).
   - otherwise → forge root is **`.forge/branch/<branch>/`**.
4. **Fallbacks** — detached HEAD, or not a git repository → fall back to **`.forge/`** and warn in one line ("not on a named branch; using the default `.forge/` root").

Branch names containing `/` (e.g. `feature/x`) become nested directories: `.forge/branch/feature/x/`.

**Everywhere in the skills, "`.forge/...`" means "relative to the resolved root" — except the two global exemptions below.** On branch `feat`, `.forge/plan.md` is physically `.forge/branch/feat/plan.md`, `.forge/backlog/` is `.forge/branch/feat/backlog/`, `.forge/adr/` is `.forge/branch/feat/adr/`, `.forge/retro/` and `.forge/CONTEXT.md` likewise, and so on. On the default branch the resolved root is literally `.forge/`, so nothing changes.

### Global exemptions (always top-level `.forge/`, never resolved)

Two paths are **always** read/written at the top-level `.forge/`, on every branch — they are shared, not per-task loop state:

- **`.forge/config.json`** — holds `defaultBranch` (which *this* rule must read before it can resolve anything — a branch-local config would be a bootstrap paradox) plus project-wide settings like `tdd`. It is one global project setting file. `fg-tdd` writes it and `fg-ask` reads `tdd` from it — both at `.forge/config.json` regardless of branch.
- **`.forge/codebase/`** — the fg-map codebase map is shared reference fuel. If it were branch-local, a freshly created branch would have an empty `codebase/` and `fg-ask` would lose the map (the whole context-rot benefit). So `fg-map` writes and `fg-ask` reads `.forge/codebase/` globally; a branch reads main's map as its base.

Everything else — backlog, plan, run, STATUS, executed, done, **adr/**, **retro/**, **CONTEXT.md** — resolves to the branch root. (These are exactly the things that collide across branches, which is the point of isolating them.)

```
skill needs a .forge path
   │
   ▼
branch = git rev-parse --abbrev-ref HEAD
default = .forge/config.json:defaultBranch (or "main")
   │
   ├── branch == default ─────────────▶ root = .forge/            (volatile gitignored, docs whitelisted — unchanged)
   ├── branch != default ─────────────▶ root = .forge/branch/<branch>/   (whole root git-tracked)
   └── detached / not a git repo ─────▶ root = .forge/  + one-line warning
   │
   ▼
read/write <root>/plan.md, <root>/adr/, <root>/backlog/, …
```

## What lives where, and why no merge conflict

- **Default branch** — root `.forge/`. Volatile state (plan/run/STATUS/backlog/executed/done) stays **gitignored**; persistent docs (adr/retro/codebase/CONTEXT.md/config.json) **tracked** via the `.gitignore` whitelist. Unchanged from before.
- **Non-default branch** — root `.forge/branch/<branch>/`, and the **whole branch root is git-tracked** (`.gitignore` whitelists `.forge/branch/`, including the volatile-type files under it). The two global exemptions (`.forge/config.json`, `.forge/codebase/`) stay at the top-level `.forge/` and are **not** copied into the branch root. Because every branch's paths are namespaced by branch name, **two branches never write the same file**, so `git merge` adds the namespaced folder without ever conflicting on forge state. (This makes branch volatile state tracked — an intentional asymmetry vs the default branch; see ADR-0011.)

## Integration

A branch's forge content is integrated into `.forge/` by **`fg-merge`** (run *after* `git merge` brings the namespaced folder into the default branch), **not** by git. fg-merge renumbers the branch's incoming ADRs to the next free numbers in `.forge/adr/` (updating cross-references), moves retros, merges CONTEXT.md terms, folds in `done/` history, and removes the branch root. The global exemptions (`config.json`, `codebase/`) are not integrated — they were never branch-local.

> **fg-merge is part 2 of this change and is not built yet** (this is part 1 — branch isolation). Until `fg-merge` ships, integration is manual: after `git merge`, a human moves the branch root's adr/retro/CONTEXT into `.forge/` and renumbers ADRs by hand. **Do not deploy branch isolation as a finished feature before fg-merge exists** (see ADR-0011 / the `branch-isolation-2of2` plan).
