# OmaSound contracts

Status: fixture lifecycle, profile model and Task 2.2 persistence implemented
under ADRs 0001 and 0002. Live-engine protocols remain undecided.

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

Only fixture/baseline is available. Other modes/layouts fail explicitly.
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
or install dependencies. It refuses an editor with unsaved changes. Missing tools/tests, unexpected lint warnings or skipped
required checks are failures. Later scopes report that they are not implemented
and return nonzero rather than passing silently.

An automated check does not replace Matt's move, focus-loss, reopen, close and
cleanup acceptance. Runtime compatibility, security evidence and marketplace
eligibility are separate verdicts.

## Profile model (Task 2.1)

```text
Side = "input" | "output"
EqSettings = { enabled: boolean, gains: number[10] }
Profile = {
  schemaVersion: 1, bandSchema: "ten-band-v1",
  id: string, revision: positive safe integer, origin: "factory" | "custom",
  name: string, input?: EqSettings, output?: EqSettings
}
Source = null | { id: string, revision: integer, name: string }
EffectiveState = { input: { eq: EqSettings, source: Source },
                   output: { eq: EqSettings, source: Source } }
ValidationResult = { ok: true, profile: Profile } | { ok: false, error: string }
validateProfile(value: unknown, library?: Profile[]): ValidationResult
applyProfile(state: EffectiveState, profile: Profile): EffectiveState
beginEdit(state: EffectiveState, profile: Profile | null,
          library: Profile[], generatedId: string): EditSession
previewEdit(session: EditSession, change: EqChange): { session: EditSession, state: EffectiveState }
cancelEdit(session: EditSession): EffectiveState
saveIntent(session: EditSession, library: Profile[]): ValidationResult
```

The accepted frequencies, gain bounds, normalized unique names, identity rules
and factory-copy semantics are specified in [ADR 0002](decisions/0002-profile-model.md).
Unknown profile/EQ fields fail validation. Operations copy caller values and
perform no I/O. Invalid transitions return an error without changing prior state.
A missing side stays unchanged, including its provenance. Ordinary device,
volume, mute and stream state lives outside this model.

An edit session contains the baseline, ID/revision, name, included sides, cached
curves, initial value signature, dirty flag and generation. `EqChange` is a name,
include, enabled, gain (index/value), or flat operation. New sides start neutral;
unchecking restores their baseline while retaining the session curve for recheck.
Dirty compares saved values rather than counting operations. Save validates the
latest draft; Cancel restores EQ only. A clean departure also restores any
preview before navigation. Factory examples are synthetic test curves.

`ProfileController.transition(state, action)` owns the in-memory library and
committed EQ, session, fake engine, pending action and errors. Navigation actions
are new/edit/apply/close; dirty navigation requires resolve(save/discard/keep).
Failed Save preserves the draft and pending action. Service emits closeApproved
only after resolution, and Panel uses it for UI, host and native close routes.
Closing retains service state. RuntimeService wraps the pure service with
durable transactions; unloading clears drafts, while saved state survives.

FakeEngine keeps requested and observed EQ separately per side. Each request
has a monotonically increasing generation; obsolete acknowledgments are ignored.
Its observations distinguish simulated success, pending, waiting, confirmed
restoration after failure and uncertainty. Partial failures never imply atomic
application. These are fixture semantics, not a settled live transport protocol.
The pure controller provides Save intent. RuntimeService confirms disk success
separately from engine observation; neither promises audible application.

## Preview source identity and transition gate

Staging has one root manifest pointing to QML/JS under a source-hash runtime
directory. Ownership records retain source and staged hashes. Preview and checks
verify the loaded Panel source URL; changed source requires stop/start. Repeated
start of unchanged source avoids rescanning the plugin and retains service state.

`./tools/check --scope model --part transitions` adds pure-model and headless
QML service tests to foundation checks. Full `--scope model` also runs storage and real-helper runtime tests. See [transition cases](profile-transition-checks.md).


## Durable fixture state (Task 2.2)

```text
CommittedValue = { profiles: CustomProfile[0..256], effective: EffectiveState }
Snapshot = { version: 1, revision: positive safe integer,
             transaction: string, value: CommittedValue }
LoadRequest = { version: 1, operation: "load" }
CommitRequest = { version: 1, operation: "commit", expectedRevision: safe integer,
                  transaction: string, value: CommittedValue }
LoadResult = { ok: true, status: "absent" | "loaded", snapshot: Snapshot | null }
CommitResult = { ok: true, status: "committed", revision: integer, transaction: string }
ErrorResult = { ok: false, code: "invalid" | "oversized" | "unsafe" | "unavailable"
                         | "busy" | "conflict" | "uncertain" }
```

`helpers/omasound_helper.py` accepts exactly one bounded JSON request on stdin,
with a 1 MiB byte limit and five-second process deadline. Its only operations are
load and commit. It serializes one ASCII JSON reply within the same byte limit
before writing stdout. No untrusted subprocess produces collected output; no
shell or child process is invoked. The QML bridge uses argv, stdin, a six-second
outer deadline and termination of its owned process on unload. Requests are
serialized; payloads also have a conservative UTF-8 bound before sending.

The fixed store root is `$XDG_STATE_HOME/omasound-fixture`, falling back to
`~/.local/state/omasound-fixture`. Tests redirect XDG_STATE_HOME to disposable
roots. Production paths and migration are outside this task. The root is private
(0700), files are private regular single-link files (0600); unsafe objects are
rejected without changing permissions or deleting them. The resolved XDG parent
is user-owned configuration; the plugin root and leaves reject symlinks. Held
directory descriptors bind leaf operations. Names and IDs never become paths.

A one-second bounded lock serializes writers. Validate the existing snapshot and
expected revision before writing. Write/fsync an exclusive temporary, replace
state.json atomically, then fsync the root before acknowledging. Failure before
publication preserves the old file. A failure after publication is uncertain;
retry the same transaction and identical value to confirm it without another
revision. Abandoned temporary files are ignored, not promoted or broadly deleted.
Corrupt, unreadable and missing state are distinct; corruption never triggers reset.

RuntimeService installs a candidate library/committed state only after acknowledgment.
Drafts stay in memory and cannot change the durable snapshot. Failed Save retains
the editor and pending navigation. Uncertainty blocks competing writes until the
same request is reconciled. A revision conflict offers explicit reload, rebases
the retained draft on the latest committed EQ and lets the user retry. No draft
is silently committed during reload. Confirmed pre-publication errors permit
editing/retry. Applying a profile and ordinary outside-editor EQ controls persist
resolved input and output, including independent provenance. Rapid outside-editor
EQ changes preview immediately and coalesce to one latest pending snapshot.

Closing UI keeps the service; stopping preview unloads it but intentionally retains
fixture storage. A new service loads only the validated committed snapshot.
Physical fixture device/volume/mute and per-app changes remain outside storage.
