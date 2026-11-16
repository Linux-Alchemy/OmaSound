# Third-party notices

OmaSound's host lifecycle (Panel.qml open/close synchronization) is adapted from
Omarchy's `shell/plugins/dev-gallery/GalleryPanel.qml`. The bar uses Omarchy's
installed `Ui.BarWidget` and `Ui.WidgetButton`; theme values use `Commons.Color`.
These imported components remain part of the installed host.

Upstream: https://github.com/omacom/omarchy

Copyright (c) David Heinemeier Hansson. MIT permission and warranty notice is
retained in the root LICENSE. OmaSound additions use the same terms.

The adapted gallery was inspected from installed package `omarchy 4.5.0-3` on
2026-11-15; its exact SHA-256 is recorded below. The package's upstream commit is
not exposed, so this digest identifies the actual source rather than attributing
it to an unverified commit. The upstream MIT notice was retrieved at
`9ac08836cf786c242e514cee8dfac8808e7ee641` (LICENSE Git blob
`f12cfa766c55541c9d8e008e310c95a721e70a97`).

No EasyEffects, JamesDSP or other processing-engine code is included.

Adapted gallery SHA-256: `ee7e0477865b8ca92d86847d9558d139379d1882d8ffc508a1051a92a07dbd1b`.
