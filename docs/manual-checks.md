# Phase 1: fixture lifecycle

Matt accepted Phase 1 window behavior on 2026-11-15. The procedure below remains
the repeatable acceptance checklist; individual actions were not separately logged.

This is a temporary arrangement, not the layout selection. All controls are
synthetic; changes should never affect sound. EQ bands are normalized fixture
positions, not approved frequencies or dB values. The baseline window is fixed
at 1200 × 800 logical pixels; production sizing remains undecided.

From the checkout, in the existing Omarchy desktop session:

```sh
./tools/preview --mode fixture --layout baseline
./tools/check --scope foundation
```

The temporary **EQ** bar entry opens/focuses the window. Stock audio and
Super + Ctrl + A retain their usual behavior. Nothing starts a second shell.

1. Click EQ. A single window appears with input/output devices, volume/mute,
   both ten-position demonstration curves and two per-app volume rows.
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

Start again if more hands-on checking is needed. A fresh preview starts with
neutral fixture bands; there is deliberately no profile persistence yet.

If source files change, stop then start to stage the new version. Preview tools
refuse to overwrite an unowned plugin or remove modified staging; preserve and
reconcile any reported change before retrying. An interrupted start retains an
ownership record so `--stop` can clean up. No generic configuration reset is used.

Record Matt's acceptance separately from automated checks. Do not advance to
Phase 2 until both gates pass and prerequisite work follows the merge workflow.
