# OmaSound — Outline

> **Status:** agreed scope, outline drafted 2026-11-14 · **Next:** PLAN.md via project-builder  
> **Build mode:** `orchestrated` — Matt designs and judges behaviour; agents implement.  
> **Working notes:** `local/SCRATCH.md` and `local/NOTES.md` (private). OmaSound is a working name.

## In one sentence

An Omarchy audio control window for shaping input/output sound through saved equalizer profiles.

## The itch and first user

Omarchy’s existing audio panel is functional for device selection and volume, but lacks the sound shaping Matt wants in that same control centre. Build for Matt’s machine first; prepare an Omarchy Plugin Marketplace release only after he is satisfied.

## Shape

**Omarchy shell plugin**, forked/adapted from `omarchy.audio`, opening a persistent, movable window initially **1200 × 800**. Preserve the existing bar/shortcut access intent, including Super + Ctrl + A. The larger surface gives the controls room; the final arrangement remains undecided. Develop in a user-owned repository, preserving upstream attribution.

## Smallest useful version

- Existing input/output device selection, volume, mute and per-app volume controls.
- Live input and output EQ, with **at most ten bands per side**; Music, Movies, Gaming and Podcast presets plus named custom profiles.
- Create profile → name → independently check **Output settings** and/or **Input settings** → adjust included EQ → Save. Both boxes start unchecked; Save requires a name and at least one checked side.
- Profiles contain EQ settings only; device selection, volume and mute stay outside profiles. Users select devices manually; active EQ carries over to the newly selected device.
- Applying a profile changes only its included sides. Omitted sides retain their settings. Restore the effective last-selected input/output settings across restarts until the user changes them.
- Editing is audible immediately. Save commits; Cancel restores pre-edit sound settings. Closing with unsaved changes offers **Save / Discard / Keep editing**.
- Per-side **EQ on/off** and **Flat reset** controls are included; they do not change device volume or mute.

This is the everyday audio-control replacement Matt intends to use, with a bounded EQ/profile feature set.

## Explicitly not doing

- Effects beyond EQ, such as noise suppression, compression or reverb.
- Automatic activity/app detection or profile switching.
- Per-app EQ or custom routing; ordinary per-app volume remains available.

## Later pile

Additional effects and automation are deferred possibilities, not commitments. Marketplace publication follows personal acceptance; it does not enlarge v1 functionality.

## Riskiest assumption

An established processing engine can provide live input/output EQ while preserving reliable device switching, volume and mute. Validate that through a bounded trial on Matt’s devices before committing to the backend. EasyEffects, JamesDSP and PipeWire filters are candidates, not a selected dependency.

## Source material

| Source | Reuse or learn from | Avoid importing |
| --- | --- | --- |
| [Omarchy audio panel](https://github.com/omacom/omarchy/tree/quattro/shell/plugins/panels/audio) | Existing controls and integration | Popup layout constraints |
| [EasyEffects](https://github.com/wwmm/easyeffects), [JamesDSP](https://github.com/Audio4Linux/JDSP4Linux) | EQ, presets, external control | Full effects-suite scope |
| [PipeWire filters](https://docs.pipewire.org/page_module_filter_chain.html) | Existing audio processing | Unnecessary custom DSP |

## Product principles

1. **User choice persists:** no surprise device changes, profile changes or startup reset.
2. **Editing is audible and reversible:** live preview must honour Save/Cancel and protect omitted sides.
3. **Existing audio control stays dependable:** new EQ must preserve the useful device, volume and mute workflow.
4. **Matt chooses the layout by using it:** implementation convenience does not settle the design.

## Delivery model

Phase 0 is complete: repository/marketplace audits produced the installed **omarchy-plugin-review** skill. Use it alongside Omarchy guidance throughout the build. Deliver small runnable slices with recorded engineering checks and Matt’s hands-on approval before advancing or merging.

## Decisions still requiring validation

1. **Separate layout branch:** compare tabs, side-by-side and vertically stacked I/O using the same controls at 1200 × 800; Matt chooses before integration.
2. **Backend:** prove live I/O processing, device changes and recovery.
3. **Distribution:** resolve deliberate built-in replacement/restore behaviour against marketplace guidance, third-party host APIs and dependency setup.

## Open questions for the plan

Band frequencies/ranges; preset curves and Podcast intent; resize/geometry behaviour; abrupt-exit recovery for unsaved edits. EQ-only profile content and per-side on/off/Flat were confirmed during planning.
