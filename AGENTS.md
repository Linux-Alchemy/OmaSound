# OmaSound agent workflow

## Resume from the plan and repository

1. Read `OUTLINE.md`, the relevant phases of `PLAN.md`, and accepted decision records before implementation. Use `local/NOTES.md` or `local/SCRATCH.md` only for context; later decisions supersede earlier proposals.
2. Inspect the current branch, HEAD, working-tree changes and relevant PR/merge state. Reconcile plan checkboxes with actual code and test evidence. A checked box alone does not prove a change was tested, pushed, merged or accepted.
3. Work is orchestrated: Matt owns design, hands-on acceptance and merges. Use `vitruvius`, `omarchy` and `omarchy-plugin-review` for their relevant work, checking availability on this machine. Execute only authorized blocks and respect the plan's phase gates.
4. Preserve user changes and other agents' work. If the plan, code or acceptance records disagree, identify the discrepancy before dependent work; do not silently overwrite another instance's decisions.

## Finish a session

Update the relevant `PLAN.md` checkboxes only when supported by evidence. Keep incomplete work unchecked and distinguish engineering completion from Matt's hands-on acceptance. Record material decisions, blockers and the next block in the appropriate plan/decision section, with references to exact commands and results under `local/evidence/` when useful. Note any running preview or temporary system change requiring cleanup.

Do not maintain a separate progress file or parallel session diary. The plan, code, Git/PR history and verification evidence provide continuity.

## Private files and multiple machines

`PLAN.md` and `local/` remain Git-ignored. They do not travel with a Git pull. If the required approved plan is missing or stale, obtain the correct copy from Matt before dependent implementation; continue useful read-only inspection meanwhile.

There is **no automatic end-of-session Tailscale synchronization**. The earlier progress-file transfer arrangement has been withdrawn. Do not copy plans or notes over another machine's working files, force-add private files, or reintroduce that synchronization without a new request. Code still follows the plan's branch/PR workflow; this instruction does not authorize commits, pushes or merges.
