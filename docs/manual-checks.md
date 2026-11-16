# Phase 1: fixture lifecycle

Matt accepted Phase 1 window behavior on 2026-11-15. The procedure below remains
the repeatable acceptance checklist; individual actions were not separately logged.

This is a temporary arrangement, not the layout selection. All controls are
synthetic; changes should never affect sound. The current bands use the accepted ADR 0002 frequencies and dB bounds. The baseline window is fixed
at 1200 × 800 logical pixels; production sizing remains undecided.

From the checkout, in the existing Omarchy desktop session:

```sh
./tools/preview --mode fixture --layout baseline
./tools/check --scope foundation
```

The temporary **EQ** bar entry opens/focuses the window. Stock audio and
Super + Ctrl + A retain their usual behavior. Nothing starts a second shell.

1. Click EQ. A single window appears with input/output devices, volume/mute,
   both ten-band demonstration curves and two per-app volume rows.
2. Drag the heading to move the window. Click another application: OmaSound
   should stay open. Click EQ again: the existing window should regain focus.
3. Cycle a fixture device; move its volume and a band, toggle mute/EQ and try
   Flat. The controls update; actual audio does not. Flat affects only that
   fixture side's bands. Switching EQ off retains its positions.
4. Close using the window's Close button, then click EQ. The fixture values
   should survive and there must still be only one window. Repeat with the
   compositor's normal close action. Try minimize/reopen if your desktop offers it.
5. Stop the preview:

   ```sh
   ./tools/preview --stop
   ```

   The window and temporary EQ entry disappear. Stock audio, other plugins and
   bar settings remain. A second stop reports no owned preview to stop.

Start again if more hands-on checking is needed. A first run without saved state starts neutral. With Task 2.2, later starts
restore saved profiles and both committed EQ sides.

If source files change, stop then start to stage the new version. Preview tools
refuse to overwrite an unowned plugin or remove modified staging; preserve and
reconcile any reported change before retrying. An interrupted start retains an
ownership record so `--stop` can clean up. No generic configuration reset is used.

Record Matt's acceptance separately from automated checks. Phase 1 is accepted
and merged; Task 2.1 does not complete the Phase 2 storage/acceptance gates.


## Task 2.1: profiles and reversible edits

Matt accepted Task 2.1 on 2026-11-16. This records overall acceptance of the
fixture editing behaviour; individual manual actions were not separately logged.

Start the preview as above; run `./tools/check --scope model --part transitions`
with no dirty editor. The baseline arrangement is still temporary. All processing
is simulated. Task 2.2 now labels the action **Save** and confirms disk success.

1. Apply Fixture Gaming, then Fixture Music. Output should say Music; input
   should retain Gaming and its curve. There is no global active-profile label.
2. New profile: both inclusion boxes begin unchecked. Try a blank name or
   neither side included; Save must be unavailable with an explanatory message.
3. Name it, include output, and edit bands. Switch EQ off: the curve remains.
   Flat zeroes the curve without changing volume/mute. Uncheck output to restore
   its previous state; recheck to recover the draft.
4. During the draft, change a fixture device, volume and mute. Cancel should
   restore EQ while keeping those ordinary controls as you left them.
5. Create input-only and combined profiles too. Save immediately after a band
   movement and edit again to confirm the latest value. Editing a factory makes
   a custom copy; its original remains available. Duplicate names are rejected.
6. With a dirty draft, use Close or the compositor close action. Keep editing
   must retain the draft; Save closes after saving; Discard closes and restores
   baseline EQ. Reopen with EQ and confirm saved profiles survive a normal close.
7. Try Apply or New profile while editing: the same three choices must resolve
   the draft before navigation. Name a profile `<b>literal</b>`: it must display
   those characters as text, without interpreting markup.
8. Stop/start preview. This task now restores
   saved custom profiles and the last committed EQ on both sides. Abandoned
   drafts must be absent.

Failure injection, missing-device observation and stale completion ordering are
covered by model/service tests; there is no live engine to exercise here.


## Task 2.2: persistence checkpoint

Matt accepted the working persistence fixture and Phase 2 on 2026-11-16. This
records overall acceptance; individual manual-test actions were not separately
logged. Changes to the selected-profile display were explicitly deferred; the
current presentation is not a final design decision.

1. Run `./tools/check --scope model` with a clean editor. It includes seven
   real-helper scenarios in a disposable offscreen runtime, without desktop
   windows or audio access.
2. Apply Gaming, then Music; save a named input-only or combined custom profile.
   Wait for the storage message to confirm Save. Stop/start preview and check
   that names, gains, enabled flags and independent side labels return.
3. Edit a saved profile without saving. Stop/start preview: the last committed
   settings should return and the abandoned draft should be absent.
4. Test rapid band movements outside the editor; wait for Saved, then restart.
   The final movement should survive. Volume/mute/device fixtures deliberately
   reset; they are not EQ profile content.

The private fixture snapshot lives under `$XDG_STATE_HOME/omasound-fixture`
(default `~/.local/state/omasound-fixture`). Preview cleanup retains it deliberately.
No automatic migration of Task 2.1's old in-memory library is provided. Corruption,
concurrent writers and interrupted writes are tested only in disposable roots;
do not damage your saved fixture data to repeat those tests. If storage is blocked,
read its error and use Retry/reload after resolving the cause. Rejected files are
preserved; the app does not silently reset them.
