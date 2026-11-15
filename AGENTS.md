# OmaSound agent continuity

## Start a session

1. Read `OUTLINE.md`, `progress.md`, and the relevant portion of `PLAN.md` before implementation. Use `local/NOTES.md` and `local/SCRATCH.md` for context when needed; later decisions supersede earlier proposals.
2. Inspect the current branch, HEAD, working-tree changes and relevant PR status. Verify the handoff against actual files; a progress note is not proof that a change is committed, pushed, tested or merged. Preserve other people's work.
3. `progress.md`, `PLAN.md` and `local/` are intentionally Git-ignored. A fresh clone will not contain them. If they are absent or conflict with another machine's handoff, request the latest private handoff before dependent implementation. Continue useful read-only inspection; do not replace missing history with an invented or empty progress record.
4. Work is orchestrated: Matt owns design, hands-on acceptance and merges. Use the available `vitruvius`, `omarchy` and `omarchy-plugin-review` skills for their relevant work. Check availability on this machine; do not assume a skill installed elsewhere exists here. Execute only authorized blocks and respect the plan's gates.

## End a session or hand off

Update root `progress.md` before ending a work session, including a blocked session. Keep the current-state summary concise and append a dated session entry with:

- Machine/worktree, branch and full HEAD SHA; PR/link and pushed/merged status when relevant.
- Completed and incomplete plan block addresses, changes made, and any uncommitted files.
- Exact verification commands and outcomes, with relative evidence paths. Identify skipped/untested work and distinguish engineering results from Matt's hands-on acceptance.
- Decisions, blockers, failed approaches worth remembering, and the smallest next action.
- What is authorized next and which approval or user decision is still required.
- Any running preview, service, process or temporary configuration the next session must know about, including cleanup state.

Update plan checkboxes only when supported by evidence. Do not mark a phase accepted without Matt's acceptance. Preserve useful prior session entries rather than rewriting their history.

## Across machines

Read ignored `local/CONTINUITY.md` for the owner-authorized transport and peer details; follow it at session start/end without publishing its private contents.

Use repository-relative references in the handoff; put machine-specific paths in clearly labelled notes. Transfer the latest ignored files separately using the owner's chosen private method. A Git pull does not transfer them. Do not publish private notes or force-add ignored files to solve synchronization.

Before another instance starts dependent work, ensure it has the latest handoff and matching code branch/commit. If two instances have diverged, reconcile both records with the actual repository state; do not blindly overwrite one by timestamp. Avoid concurrent writers to the same private handoff.
