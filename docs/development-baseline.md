# Development baseline

Foundation inspected 2026-11-15; Task 2.1 extended 2026-11-16. Foundation engineering checks pass on this
baseline; Matt accepted Phase 1 window behavior on 2026-11-15.

| Component | Installed package |
| --- | --- |
| Omarchy | 4.5.0-3 |
| Quickshell | 0.3.2.r7.g2b4501a-1 |
| Qt declarative | 6.12.0-2 |
| Python | 3.14.8-1 |
| Node.js | 26.12.0-1 |

These identify the inspected machine, not a supported-version range. Use the
package/`omarchy version` result: the packaged `version` text file still says
`4.0.0.alpha`. No package has been installed or upgraded for OmaSound.

## Owning sources inspected

Paths below are relative to the installed read-only `/usr/share/omarchy` tree.
Private evidence records SHA-256 hashes of the inspected files. The package is
not a Git checkout; its exact upstream commit has not been established. Do not
label the upstream reference revision as the installed package's revision.

| Source | Finding / consequence |
| --- | --- |
| `shell/plugins/panels/audio/manifest.json` | Stock audio declares only bar-widget, with Panel.qml as the widget entry. |
| `shell/plugins/panels/audio/Panel.qml` | Device selection, output/input volume and mute, per-app playback levels, keyboard navigation and primitive device snapshots are useful patterns for later adaptation. |
| Same audio Panel | Starts PipeWire trackers, peak monitor and availability/volume helper processes; omit these entirely from fixtures. |
| Same audio Panel | Uses first-party media lookup and summons stock OSD; these do not automatically carry over to a third-party plugin. |
| `shell/services/PluginShellApi.qml`, `shell/Ui/PluginBarApi.qml` | Own-ID shell operations and scoped service lookup; not a security sandbox. |
| `shell/shell.qml` | `isBarWidgetPanelPlugin` excludes plugins with a separate panel kind; panel loader injects own service and respects keepLoaded. |
| `shell/plugins/dev-gallery/GalleryPanel.qml` | FloatingWindow and open/close host synchronization are relevant reference patterns. |
| `bin/omarchy-plugin-enable`, `bin/omarchy-plugin-disable` | Enabling can place a bar widget; disabling alone does not constitute complete restoration of preview configuration. |
| `bin/omarchy-plugin-validate` | Validates manifest/kind entry points and rejects symlinks/reserved IDs; does not prove runtime correctness. |

The later live adapter must preserve physical-volume resolution behind virtual
DSP endpoints, safe transient-node handling and manual device/volume/mute choices.
None of that behavior is implemented or validated by this inventory.

## Provenance

Omarchy upstream: https://github.com/omacom/omarchy.
Reference revision available from the foundation audit:
`9ac08836cf786c242e514cee8dfac8808e7ee641`.
Its root LICENSE was independently retrieved on 2026-11-15: MIT permission notice,
copyright David Heinemeier Hansson. Preserve that full notice when adapting code.
Panel lifecycle code adapts the installed gallery pattern. The exact adapted
source digest and full MIT notice are retained in THIRD_PARTY_NOTICES.md and LICENSE.

## Commands and verification

Use `/usr/lib/qt6/bin/qmllint` and `/usr/lib/qt6/bin/qmlformat` (both 6.12.0).
The unqualified commands on this machine are older 1.0 tools and are not the
foundation gate. Node is invoked as `/usr/bin/node` to avoid shim-dependent versions.
Python uses the existing system standard library only.

```sh
./tools/preview --mode fixture --layout baseline
./tools/check --scope foundation
./tools/preview --stop
```

The check resolves `qs` to the installed shell through a temporary import-path
symlink outside the staged plugin, runs Qt 6 lint with `--ignore-settings -W 0`,
compares qmlformat output byte-for-byte, runs four Node fixture tests and thirteen
Python cleanup/ownership tests, checks Git hygiene and inspects the running host.
To apply QML formatting: `/usr/lib/qt6/bin/qmlformat -i FILE.qml`.

The staged plugin contains no symlinks. The checker requires the matching preview
already running, and briefly hides/reopens it to verify instance reuse. `hyprctl
clients -j` confirms one floating 1200 × 800 client. Unimplemented scopes return nonzero.
No build/compiler/native sanitizer step is applicable to this QML/JS/Python slice.

The host emits its known scanner warnings that external plugin QML directories
are outside the shell config folder. The initial registration race also produced
an unknown-plugin warning before it was fixed by waiting for registry discovery.
These are recorded separately from project lint; no lint categories are disabled.

Preview refuses incomplete local bar configuration rather than letting the host
normalize unrelated sections. Owned staging changes are refused rather than
overwritten. Tests cover concurrent unrelated configuration edits, registration
waits, failed enable, repeated start/stop, modified files, wrong ownership,
symlinks/FIFOs and interrupted ownership publication.

Runtime compatibility: loaded successfully in this host, with automated
close/reopen and single-window geometry checks. Matt subsequently confirmed the
window behaves as expected and accepted the Phase 1 lifecycle. Individual
manual-test observations were not recorded separately. Security evidence:
fixture-only source review plus bounded input and owned-cleanup tests. Marketplace
eligibility: not assessed; the development identity is not a release candidate.


Task 2.1 adds seventeen pure-model Node tests and five QML service scenarios
(seven QtTest passes including setup/cleanup). The canonical transition scope
uses `/usr/lib/qt6/bin/qmltestrunner` with `QT_QPA_PLATFORM=offscreen`,
`QT_QPA_PLATFORMTHEME=generic` and `QT_QUICK_CONTROLS_STYLE=Basic`. This exercises
the actual Service.qml under Qt without requiring another desktop shell.

The thirteen Python cases also check stale loaded-source rejection and distinct
runtime paths after source changes. The installed host was observed to cache QML
across same-path staging; source-specific runtime directories prevent that reuse.
Repeated start does not rescan an unchanged preview or reset its in-memory library.
The loaded host's dirty native close, host hide and shared Close handler were
exercised separately from headless tests. These observations do not replace Matt's
hands-on acceptance or prove live audio/persistence behaviour.


## Task 2.2 verification extension

The full model scope adds three stored-state Node tests (20 model tests total),
fourteen Python filesystem/helper tests (27 Python
cases total), plus seven real-helper persistence scenarios via `tools/check-runtime`.
Qt's standalone qmltestrunner cannot load this package's statically registered
Quickshell process plugin. The pure service remains independently tested there;
RuntimeService supplies the actual process adapter in a disposable, offscreen
Quickshell runtime. It has no desktop windows, live audio or production state.
The runner requires explicit completion markers, fails on warnings/errors, bounds
runtime and removes its temporary configuration/state. It is not another desktop
shell. Restart, failed Save, concurrent conflict, lost acknowledgment and rapid
EQ coalescing exercise the real helper, not a substituted implementation.

Strict project lint/format now covers nine QML components including RuntimeService
and StateBridge. No tools or dependencies were installed. Storage helpers use
Python's standard library. Security evidence covers bounded passive JSON, fixed
operations/paths, private descriptor-based file access and atomic publication;
marketplace eligibility and real DSP behaviour remain unassessed.
