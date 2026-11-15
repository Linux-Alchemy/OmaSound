# ADR 0001: Hosted fixture window and isolated development identity

- **Status:** Accepted by Matt on 2026-11-15
- **Date:** 2026-11-15

## Context

OmaSound needs a persistent movable window inside the existing Omarchy shell.
The stock audio plugin is a bar widget whose Panel owns a popup. Copying that
entry point wholesale would also start real PipeWire access, helper processes
and input metering during a fixture-only phase.

The inspected Omarchy 4.5.0-3 host supports a separate panel entry point alongside
a bar widget and service. Its routing explicitly sends combined bar-widget/panel
plugins through the panel loader. Third-party shell facades permit control of the
plugin's own panel and service; the stock audio panel's media-service and OSD calls
must not be assumed available. These facades are API boundaries, not a sandbox.

## Decision

Accepted decision:

1. Use the temporary ID `linux-alchemy.omasound-dev`, with `bar-widget`, `panel`
   and `service` kinds. Keep one root manifest. Do not declare `clonedFrom`,
   register `omarchy.audio` IPC, or replace the stock audio bar entry/shortcut
   during Phase 1. Production replacement remains a later decision.
2. `BarWidget.qml` requests `shell.summon(ownId, "{}")`; it does not toggle the
   window shut on a repeated click. `Panel.qml` owns one `FloatingWindow`, initially
   1200 × 800. Use `keepLoaded: true` so closing hides the window while preserving
   its instance and service. Closing routes through the host's own-ID `hide` API.
   Focus loss does not close it. Disable/unload destroys owned UI and fixture state.
3. `Service.qml` owns synthetic input/output, volume, mute, stream and EQ display
   state. Phase 1 has no PipeWire/MPRIS imports, microphone capture, real engine,
   profile persistence or application of audio settings. EQ controls are visibly
   fixtures with no approved band frequencies or gain schema implied.
4. Use installed QML/JavaScript and Python's standard library for preview tooling;
   add no dependencies. Public boundaries use QML/JavaScript signatures and
   documented JSON-shaped values, with Python annotations where tooling needs them.
   Profile/storage/engine contracts remain provisional until their assigned phases.
5. Stage an explicit allowlist into a separate user-plugin directory bearing the
   development ID. Refuse an existing unowned installation. Record the owned
   preview footprint under ignored `local/`; add one temporary bar entry. Stop
   unloads that ID, removes only owned staging and restores only its configuration
   changes, preserving concurrent unrelated edits. Never restore an entire old
   shell configuration over newer user changes. A cleanup conflict must be reported.
6. Adapt only necessary Omarchy control patterns, retain upstream MIT notice and
   source attribution, and record the exact source identity for every copied part.
   Do not import stock audio side effects just to reuse its visual controls.

## Consequences

The preview can exercise a real third-party host path without taking over daily
audio. Multiple bar instances must summon the same host-owned panel. A close
does not imply service shutdown, which also suits later ongoing EQ processing.

The preview deliberately makes a small reversible change to user plugin/bar
configuration. Start/stop and conflict recovery therefore need meaningful tests,
not merely copying a folder. Native window activation and compositor sizing still
require runtime verification: source inspection alone does not prove focus/reuse
or that a 1200 × 800 window remains floating on the user's compositor. No global
window-rule workaround is approved by this proposal.

No final layout, EQ schema, engine, production ID or marketplace eligibility is
settled here. A plain temporary arrangement is solely a lifecycle test surface.

## Rejected alternatives

- **Copy the stock audio Panel wholesale:** popup lifecycle, real audio access and
  first-party host assumptions conflict with this phase's contract.
- **Launch a second Quickshell instance:** duplicates the desktop host and bypasses
  the plugin lifecycle the foundation must prove.
- **Own a window in each bar widget:** risks duplicate windows on multiple monitors.
- **Claim the stock audio identity during development:** disrupts normal controls
  before replacement and restoration have been designed and accepted.
- **Restore all of shell.json from a backup:** overwrites unrelated concurrent edits.

## Evidence and acceptance

See `docs/development-baseline.md` for installed versions and source locations,
and `docs/contracts.md` for the proposed Phase 1 interfaces. Private raw inventory
and file hashes are in `local/evidence/phase-1/inventory.json`.

Matt approved ADR 0001 and authorized Task 1.1 on 2026-11-15. Runtime engineering and hands-on acceptance remain separate gates.
