# OmaSound contracts

Status: Phase 1 implemented under accepted ADR 0001. EQ profiles, storage and
engine protocols are not frozen.

## Window lifecycle

```text
Window.open(payloadJson: string): void
Window.close(): void
```

The host invokes these on the single panel instance. Phase 1 accepts only an
empty payload or an empty JSON object; reject malformed, oversized or unsupported
payloads before changing state. A 1024-byte ASCII payload ceiling applies to this
otherwise parameterless entry point. Repeated open shows/focuses the existing
window, including after minimize; it must not create another instance. Close hides
UI and synchronizes host open state without destroying service state. Focus loss
does nothing. Unload releases owned objects. Matt accepted the Phase 1 window
lifecycle on 2026-11-15; the manual procedure remains in `manual-checks.md`. The baseline fixture uses fixed 1200 × 800 size hints;
production resizing is undecided.

## Fixture preview

```text
Preview.start(mode: "fixture", layout: "baseline"): PreviewResult
Preview.stop(): CleanupResult
PreviewResult = { ok: boolean, changed: boolean, message: string }
CleanupResult = { ok: boolean, changed: boolean, message: string }
```

The CLI returns 0 only on confirmed success; failures return nonzero and an
actionable diagnostic. Installation or an IPC request alone does not establish
that QML loaded or the window is visible. Repeated start reuses owned staging;
repeated stop is safe. Unowned staging, invalid ownership records and conflicting
configuration edits are errors, not permission to delete arbitrary paths.

Only fixture/baseline is available in Phase 1. Other modes/layouts fail explicitly.
No second shell process, implicit dependency installation, production profile
access or audio mutation is permitted. Staging excludes private plans, evidence,
Git internals, tests and arbitrary checkout files; the installable tree has no
symlinks. Cleanup preserves unrelated shell/bar settings and plugin installations.

## Verification command

```sh
./tools/check --scope foundation
```

Start the fixture explicitly before running this check. It runs installed
manifest validation against an allowlisted temporary plugin, strict Qt 6
lint/format checks with resolved host imports, fixture and cleanup tests, then
checks the matching loaded preview, repeated open and close/reopen identity.
It confirms one floating 1200 × 800 client through read-only Hyprland inspection.
The checker briefly hides/reopens the owned window; it does not stage a plugin
or install dependencies. Missing tools/tests, unexpected lint warnings or skipped
required checks are failures. Later scopes report that they are not implemented
and return nonzero rather than passing silently.

An automated check does not replace Matt's move, focus-loss, reopen, close and
cleanup acceptance. Runtime compatibility, security evidence and marketplace
eligibility are separate verdicts.
