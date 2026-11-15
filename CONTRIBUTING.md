# Contributing to OmaSound

OmaSound uses pull requests so behavior, evidence and acceptance remain visible.
Matt owns design decisions, hands-on acceptance and merges.

- `master` is accepted history. Feature work belongs on a named task branch.
- Work only within the agreed task and accepted architecture decisions.
- Run the applicable checks and report actual output, failures and limitations.
- Use the PR template; distinguish engineering completion from hands-on approval.
- Agents do not merge without Matt's explicit instruction. Review fixes stay on
  the same branch; no force-push without authorization.
- Never commit private plans, `local/`, recordings, generated output or unrelated
  changes. Do not synchronize private working files between machines implicitly.
- Approval to build locally does not authorize publishing or contacting others.

## Foundation verification

On an existing Omarchy session with the documented installed tooling:

```sh
./tools/preview --mode fixture --layout baseline
./tools/check --scope foundation
./tools/preview --stop
```

The preview explicitly stages a temporary plugin and bar entry. The check itself
does not install it: it requires the matching preview already running and briefly
closes/reopens its window. Later scopes are unimplemented and fail explicitly.
No dependencies are downloaded by these commands.

Prepare a focused commit and PR only when authorized. Matt reviews the proposed
behavior, runs the manual checkpoint and chooses whether to merge. Public
contracts and decisions live in `docs/`; machine-specific evidence stays local.
