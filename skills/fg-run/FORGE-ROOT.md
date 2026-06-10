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

### Read overlay for permanent grilling fuel (non-default branches)

A fresh branch root starts empty, but the default branch's permanent docs are git-tracked and already present in the checkout at top-level `.forge/`. So on a non-default branch, **reads of the permanent grilling fuel (`CONTEXT.md`, `adr/`, `retro/`) overlay the branch root on top of the top-level `.forge/`** — read both, branch entries winning on conflict — the same rationale as the `codebase/` exemption (a branch reads main's docs as its base). **Writes are unchanged**: new terms/ADRs/retros go to the branch root only (that is what prevents merge conflicts), and new-ADR numbering stays branch-root `max+1` (fg-merge renumbers at integration — do not mint from the combined max). Exclude `adr/retired/` at both levels. Volatile state (backlog/plan/run/STATUS/executed/done) never overlays — it is strictly branch-rooted. (Amends ADR-0011 — see its 개정 note.)

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
- **Non-default branch** — root `.forge/branch/<branch>/`, and the **whole branch root is git-tracked** (`.gitignore` whitelists `.forge/branch/`, including the volatile-type files under it). The two global exemptions (`.forge/config.json`, `.forge/codebase/`) stay at the top-level `.forge/` and are **not** copied into the branch root. Because every branch's paths are namespaced by branch name, **two branches never write the same file**, so `git merge` adds the namespaced folder without ever conflicting on forge state. (This makes branch volatile state tracked — an intentional asymmetry vs the default branch; see ADR-0011.) Branch forge state must be **committed on the branch** like any code change — an uncommitted branch root never reaches the default branch for fg-merge to integrate.

## Integration

A branch's forge content is integrated into `.forge/` by **`fg-merge`** (run *after* `git merge` brings the namespaced folder into the default branch), **not** by git. fg-merge renumbers the branch's incoming ADRs to the next free numbers in `.forge/adr/` (updating cross-references), moves retros, merges CONTEXT.md terms, folds in `done/` history, and removes the branch root. The global exemptions (`config.json`, `codebase/`) are not integrated — they were never branch-local. See `skills/fg-merge/SKILL.md`.
