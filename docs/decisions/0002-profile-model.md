# ADR 0002: Independent EQ profiles and reversible editing

- **Status:** Model accepted by Matt on 2026-11-16; storage decisions reserved for Task 2.2
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
