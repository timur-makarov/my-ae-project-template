# Standing Definition of Done

Acceptance criteria (the ticket Done Contract) answer "did we build this thing?"
This checklist answers "is it finished to our standard?" Both must hold.

LOW tickets: Correctness + Quality.
MEDIUM: + Integration.
HIGH: + Ship-readiness.

## Correctness
- [ ] Done Contract checks ran (command + exit code pasted)
- [ ] New behavior has a test that failed without the change and passes with it
- [ ] Existing tests pass; no skips, deleted assertions, or silenced checkers (floor-guard)

## Quality
- [ ] Diff is scoped to the ticket; noticed-not-touching listed in the PR
- [ ] No unasked abstraction; Ponytail/YAGNI held
- [ ] Lint / types / project verify stamp green

## Integration
- [ ] Migrations, config, env, feature flags accounted for
- [ ] Public interfaces stayed backward compatible or followed expand/contract
- [ ] `new_deps:` lists every added package if a lockfile changed

## Ship-readiness
- [ ] Rollback field is a real command or an expand-contract plan
- [ ] Threat boundary reviewed for untrusted input (security fan-out on HIGH risk_paths)
- [ ] Human merge for HIGH (`risk.high_requires_human_merge`)
- [ ] Critic watchlist names the decaying fact to watch after merge
