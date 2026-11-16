# OmaSound

An Omarchy audio control window for input/output EQ and saved profiles.

**Current state:** Task 2.1 fixture profile editor. Create, apply and edit EQ-only
profiles with independent input/output settings and reversible drafts. Controls
are synthetic and do not alter audio. Profiles are saved in memory only;
disk storage, live EQ and final layout selection are still ahead.

## Try the fixture

Use an existing Omarchy desktop session. See the [tested tool baseline](docs/development-baseline.md).
No package installation is performed.

```sh
./tools/preview --mode fixture --layout baseline
./tools/check --scope foundation
./tools/check --scope model --part transitions
./tools/preview --stop
```

Preview stages `linux-alchemy.omasound-dev` under the user's Omarchy plugin
directory and adds a temporary **EQ** bar entry. Clicking it opens one persistent
1200 × 800 fixture window. Closing preserves in-memory fixture values; stopping
unloads/removes the owned preview and its bar entry. The stock audio control and
shortcut remain in place. Preview ownership metadata stays in ignored `local/`.

The check requires a running matching fixture, briefly closes/reopens it, and
verifies manifest, strict Qt 6 lint, QML formatting, fixture logic, cleanup tests
and host lifecycle. The model transition scope adds profile and QML service tests.
Checks refuse a dirty editor; save or discard its draft first. Missing
prerequisites are failures. Full `--scope model` awaits Task 2.2 storage checks.

Follow the [manual checks](docs/manual-checks.md) for lifecycle and profile acceptance.
See [contracts](docs/contracts.md), [ADR 0001](docs/decisions/0001-host-boundary.md)
and [contributing](CONTRIBUTING.md) for boundaries and workflow.

Omarchy-derived patterns retain upstream [MIT licensing](LICENSE) and
[attribution](THIRD_PARTY_NOTICES.md). Marketplace eligibility is not assessed.
