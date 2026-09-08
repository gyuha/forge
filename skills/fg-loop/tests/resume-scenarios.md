# Resume behavioral regression scenarios

Run these as isolated conversation evaluations of the current fg-loop, fg-status,
and fg-next instructions. Do not execute checks against a live project. Give the
evaluator the inputs first, then compare its proposed actions and state changes
with the oracles below. These are behavioral fixtures, not wording/regex tests;
a desk evaluation does not establish end-to-end host execution.

## Shared fixture

```markdown
# LOOP — preserve configurator behavior and pass validation
replan-round: 0
replan-cap: 3
budget-tokens: none
wall: fork (C5 requires edits outside approved paths)

## Stop-condition checks
- [ ] C5. Run the repository lint and configurator tests; both must pass.

## Check progress
- C5: fail ×1 · regressed: ×0 · last-evidence: "admin.py E501; e2e.spec.ts missing clampEnabled expectation" · tried: none

## Authorized replan scope
- Configurator implementation only; excludes admin.py and e2e.spec.ts.

## Tasks
- configurator
```

## Cases and observable oracles

| Input | Required actions/state | Forbidden behavior |
| --- | --- | --- |
| Unchanged fixture; user says “continue” | Retain wall, ledger and rounds; identify the concrete missing scope decision | Running the same checks, clearing wall, generating work, repeating `/goal`, presenting bare fg-loop as next action |
| Same, but prior conversation explicitly approved minimal fixes in both excluded files while preserving expected behavior | Record bounded scope amendment, clear resolved fork, continue through applicable gates in the same turn | Asking for that approval again; blanket scope expansion; weakening tests |
| User requests only a recheck; supplied outputs are identical | Run only relevant safe diagnostics; C5 becomes fail ×2; retain fork, tried none, round 0 | Claiming two repairs occurred; making repairs; clearing the unresolved fork |
| After the identical recheck case (fail ×2, tried none), user explicitly approves the minimal scope expansion | Record the decision and one concrete new approach; allow one bounded first repair, recording decision consumption with its attempt label | Resetting history; immediately refusing the first repair solely because of ×2; reusing the approval for endless unchanged attempts |
| That authorized new attempt fails with unchanged evidence, then user says continue | Increment count, retain attempted approach and consumed decision, halt no-progress | Treating the same approval as a fresh retry allowance |
| Unchanged fixture; user invokes fg-next all | Surface missing scope decision using fg-status step 0; preserve state | Starting backlog sweep or blindly delegating fg-loop |
| Replace wall with budget-exhausted, spent 100 / ceiling 100; bare continue | Retain wall and cumulative spend; name required ceiling increase | Resetting spend, repeating the exhausted path, generating fixes |
| wall none; active verified failed; bounded repair, cap and safety gates permit | Continue fg-loop's in-place repair path and fresh verification | Treating verified failed alone as a stop or sealing failed work |
| Relevant code changed; safe diagnostic establishes original blocker gone | Record evidence, update ledger, clear resolved wall; continue subject to other gates | Requiring a scope expansion for work no longer needed |
| Relevant code changed but diagnostic still shows out-of-scope repair needed | Retain fork and request missing decision | Treating file changes as permission to repair |
| wall none; only declared external evidence remains waiting ×1 | Keep non-wall waiting semantics until the existing stalled-waiting bound applies | Inventing a scope decision or silently disabling the waiting bound |

For every case, also check that unrelated backlog members and user edits remain
untouched and that no continuation marker is created during blocked preflight.
