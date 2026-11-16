# ADR 0002: Independent EQ profiles and reversible editing

- **Status:** Model and Task 2.2 storage addendum accepted by Matt on 2026-11-16
- **Date:** 2026-11-16

## Context

A profile may contain input, output or both. Applying an output-only profile must
preserve the current input intent, including its origin. Editing must preview
only included EQ, and cancelling must not undo manual device, volume or mute
changes. Phase 2 proves these rules against fixtures before live processing.

## Decision

Accepted model decisions:

### Bands and neutral state

- One versioned ten-band schema shared by input and output: **31.25, 62.5, 125,
  250, 500, 1000, 2000, 4000, 8000 and 16000 Hz**.
- Each gain is a finite number in **−12 to +12 dB**. The UI steps in **0.5 dB**;
  validation permits other finite values within the range, avoiding forced
  rounding of future engine observations. Frequency/Q/filter type are not editable
  in v1. Engine realization and headroom remain ADR 0003 decisions; these values
  are the accepted control contract, not a claim about a chosen backend.
- First-run effective EQ is flat and bypassed. A newly included side in a new
  profile also starts flat and bypassed. Enabling EQ preserves its stored gains;
  Flat zeroes gains and preserves the enabled flag.

### Profile identity and names

- A profile has schema version, band-schema ID, stable generated ID, positive
  revision, origin (`factory` or `custom`), display name and optional input/output
  EQ settings. At least one side is required. Unknown fields are rejected,
  including device, volume, mute and routing fields.
- Names are trimmed and Unicode-normalized (NFC), **1–64 Unicode code points**,
  with control characters rejected. Names are display text, never file paths.
  Duplicate normalized names are rejected case-insensitively across the library;
  renaming the same custom profile is allowed.
- Custom IDs are generated independently of names and checked for collision.
  Editing a custom profile retains its ID and increments its revision on Save.
  Factory profiles are immutable: editing creates a custom copy with a new ID
  and an available suggested copy name. No delete/import/export feature is added.
- Factory examples in Task 2.1 are explicitly synthetic; no production preset
  curves or Podcast intent are selected here.

### Editing and independent effective state

- A new editor has a blank name and both inclusion boxes unchecked. Save is
  disabled until name and included EQ validate. EQ editing is available only for
  included sides. Rechecking a side restores its retained draft within that session.
- Capture an independent effective-EQ baseline before any preview. Editing an
  existing profile previews its included settings; cancelling restores the full
  pre-edit EQ intent and provenance. Device/volume/mute state lives elsewhere.
- Unchecking an included side restores that side's baseline immediately and
  removes it from the Save payload. The other side is untouched.
- Dirty is a comparison with the editor's initial name/inclusion/settings, not
  merely a flag set on every event. Returning to the initial values clears it.
- Apply, open-another-editor and close requests during dirty editing pause for
  **Save / Discard / Keep editing**. A failed Save retains the editor and pending
  action. A clean editor still restores its preview baseline before leaving.
- Save takes the latest draft, validates it and captures its latest generation.
  Task 2.1 saves only in memory and labels that limitation explicitly. Task 2.2
  must supply the durable commit result before any UI claims disk persistence.
- Applying a saved profile replaces only its included side(s). Outside an editor,
  bypass/Flat/gain changes alter effective EQ and mark that side as custom; they
  never silently rewrite a named profile. Inside an editor they remain drafts.

### Requested versus observed state

- Keep committed EQ intent, current preview intent and simulated engine
  observation distinct. Input and output each retain their own provenance.
- Every preview/restore/apply has a monotonically increasing generation. Ignore
  an acknowledgment for an older generation, including one arriving after Cancel.
  The fake bridge exposes delayed/stale/failure cases to tests without defining a
  live-engine transport protocol.
- For partial failure, restore the previously observed EQ where confirmed; mark
  an unconfirmed restoration as uncertain. Never report an atomic two-side
  transaction or an applied state from merely issuing a request.
- Missing-device simulation retains requested EQ with a waiting observation.
  Saving a valid profile can succeed in memory while its application is waiting;
  save status and application status remain separate.

## Consequences

The same model can drive every later layout. Ten fixed bands give a bounded UI
and schema, while keeping the real DSP mapping and headroom decision in Phase 3.
The ±12 dB limit is a product choice, not clipping protection.

In-memory Save is deliberately temporary in Task 2.1. Profiles do not survive
preview unload until Task 2.2. Storage schema, coherent profile/effective-state
publication, revision conflicts and recovery still need the later ADR completion.

## Rejected alternatives

- **One globally active profile:** loses mixed input/output provenance.
- **Snapshot all audio controls on edit:** Cancel would undo the user's manual
  device/volume/mute decisions.
- **Overwrite factory profiles:** prevents a dependable factory baseline.
- **Use names as IDs or file paths:** makes rename change identity and couples
  user-facing text to storage.
- **Persist every preview movement:** abandoned drafts would become startup state.
- **Assume every request was applied:** hides missing devices, failures and stale
  completions; fixtures must prove these distinctions before live integration.

## Acceptance

Matt accepted the proposed model package, including numerical band settings, on
2026-11-16 and authorized implementation of Task 2.1. Storage acceptance is separate.


## Task 2.2 storage decision — 2026-11-16

Implementation decision under Matt's authorization to continue Task 2.2 after
merging Task 2.1. This addendum supersedes the fixture runtime's in-memory-only
Save behaviour; the pure model remains unchanged. Matt subsequently confirmed
the persistence fixture works as expected and accepted Phase 2 on 2026-11-16.

- Persist one version-1 `state.json` snapshot containing a store revision,
  last transaction ID, the custom-profile library and both resolved committed
  EQ sides/provenance. Factory fixtures remain code-owned. No device, volume,
  mute, transient engine observation or draft is stored. Maximum 256 custom
  profiles and 1 MiB per document/request; validate both languages at boundaries.
- The development helper uses only `$XDG_STATE_HOME/omasound-fixture` (fallback
  `~/.local/state/omasound-fixture`). Tests override XDG_STATE_HOME with a
  disposable directory. This is separate from future production state.
  Preview stop removes the temporary installation but retains this fixture state.
- Names never become paths; IDs remain data inside the single snapshot. Hold
  the private root directory descriptor, reject unsafe leaf objects, and use
  owner-only directories/files. Respect the user's resolved XDG base location;
  refuse a symlink at the plugin-owned root or any store leaf.
- Serialize writers with a bounded advisory lock. Commit requires the current
  revision, writes an exclusive temporary file, fsyncs it, atomically replaces
  state.json, then fsyncs the directory before acknowledging success. A failure
  before replace preserves the previous snapshot. Never silently initialize over
  corrupt/unreadable state. Interrupted temporary files are ignored, not loaded
  or broadly deleted. Recovery selects only a validated complete state.json.
- A transaction ID allows an identical retry after a lost acknowledgment to
  confirm an already-published commit. Failures after publication/transport loss
  remain unconfirmed until retry/reconciliation; the UI must not claim success
  or permit a competing save meanwhile. Confirmed pre-publication failure keeps
  the editable draft and pending navigation. Revision conflicts block writes
  until an explicit reload, with the draft retained for retry.
- The one-shot Python helper accepts only load/commit through bounded stdin and
  emits one bounded ASCII JSON reply. It never invokes a shell or child process.
  Serialize requests in QML; deadline/termination applies to the owned process.
  Save/navigation completes only after a validated durable acknowledgment.
  Outside-editor EQ changes commit the resolved sides; drafts never do.
- Missing storage is neutral first run; invalid/unavailable storage is a visible
  blocked state with Retry. Reload/retry never silently overwrites rejected data.
  Abnormal exit restores the last published committed snapshot, not a draft.

A single snapshot avoids split library/effective-state commits and separate
profile filenames. It deliberately does not provide automatic backup selection,
imports, deletion UI, production paths or a live-engine transport.
