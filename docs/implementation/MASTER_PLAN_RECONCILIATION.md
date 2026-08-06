# Master-Plan and Ledger Reconciliation

> **Status:** Active
>
> **Created:** 2026-08-05
>
> **Authority:** The production master plan defines feature scope. This record
> maps the former implementation-ledger numbering to that scope and is the
> canonical bridge used by the ledger and traceability matrix.

## Status Rules

`IMPLEMENTED_UNVERIFIED` means that an implementation task has completed and
has automated evidence, but its named QA task has not independently accepted
the complete user workflow. `PARTIALLY_IMPLEMENTED` means only the listed
runtime/data core exists; its authoring UI, validation, persistence, or
clean-consumer acceptance work remains a separate master-plan task. Legacy
requirement acceptance is recorded only in the traceability matrix after its
named verification task completes; it does not promote the mapped master-plan
scope to complete.

`VERIFIED_LEGACY_CORE` denotes a legacy requirement accepted by its named QA
task while the mapped master-plan scope still has separately recorded work.

## Current Completion Update — 2026-08-06

`docs/implementation/evidence/QA-COMPLETION-001/` is the accepted verification
record for `QA-WPN-001`, `QA-SOL-001`, `QA-WPA-001`, `QA-CHR-001`, `QA-GMD-001`,
`QA-MED-001`, `QA-RUL-001`, `QA-LNK-001`, `QA-EXP-BATCH-001`, `QA-GDT-001`, and
`QA-PRF-001`. Its scoped acceptance tests, clean-consumer check, and full
regression gate supersede earlier `IMPLEMENTED_UNVERIFIED` entries for those
groups. The traceability matrix is the per-requirement source of truth; only
the `SMP-*`, `DOCS-*`, and `REL-*` ranges remain pending `QA-REL-001`.

## Legacy-to-Master Mapping

| Legacy implementation work | Master-plan scope | Reconciled status | Remaining authoritative task(s) | Notes |
|---|---|---|---|---|
| `GRID-001` | `FAC-001` | VERIFIED_LEGACY_CORE | `FAC-001`, `QA-FAC-001` | Directional data schema accepted by `QA-GRID-001`. |
| `GRID-002` | `FAC-007` | VERIFIED | - | Runtime direction selection plus `FAC-002` direction-set editing, `FAC-007` hard-switch authoring, and `FAC-010` scrub preview accepted by `QA-FAC-001`. |
| `GRID-003` | `FAC-005`, `FAC-006` | VERIFIED | - | Data-level slot swap/mirroring and `FAC-005`/`FAC-006` reachable authoring workflows accepted by `QA-FAC-001`. |
| `GRID-004` | `FAC-008`, `FAC-012` | VERIFIED | - | Runtime crossfade/pixel opt-out, `FAC-008` crossfade selection, `FAC-010` preview, and `FAC-012` pixel authoring accepted by `QA-FAC-001`. |
| `GRID-005` | `FAC-009` | VERIFIED | - | Equal-topology interpolation and `FAC-009` directional mesh authoring/validation accepted by `QA-FAC-001`. |
| `GRID-006` | `FAC-011` | VERIFIED | - | Missing-cell data diagnostics, assignment/batch workflows, and `FAC-011` correction navigation accepted by `QA-FAC-001`. |
| Legacy state-machine core in `GRID-001`–`GRID-006` | `BLD-001`–`BLD-005`, `STM-001`–`STM-004`, `RUL-001`–`RUL-005` | IMPLEMENTED_UNVERIFIED | `QA-RUL-001` | Masked/additive blending, graph authoring, nested-machine export, time/event rules, diagnostics, and deterministic parity are implemented. |
| `EXP-001` | `EXP-001`, `EXP-002`, `EXP-009`–`EXP-012` | IMPLEMENTED_UNVERIFIED | `QA-EXP-BATCH-001` | Versioned envelopes, deterministic serialization, batch variants, cancellation/progress, artifact validation, and output-opening workflows are implemented. |
| `EXP-002` | `EXP-005` | VERIFIED_LEGACY_CORE | `EXP-009`–`EXP-012` | Deterministic atlas packing accepted by `QA-EXP-001`. |
| `EXP-003` | `EXP-003` | VERIFIED_LEGACY_CORE | `EXP-009`–`EXP-012` | PNG/WebP image-sequence export accepted by `QA-EXP-001`. |
| `EXP-004` | `EXP-004` | VERIFIED_LEGACY_CORE | `EXP-009`–`EXP-012` | Spritesheet JSON/XML export accepted by `QA-EXP-001`. |
| `EXP-005` | `EXP-006` | VERIFIED_LEGACY_CORE | `EXP-009`–`EXP-012` | GIF export accepted by `QA-EXP-001`. |
| `EXP-006` | `EXP-007` | VERIFIED_LEGACY_CORE | `EXP-009`–`EXP-012` | MP4/WebM pipeline accepted by `QA-EXP-001`. |
| `EXP-007` | `EXP-008` | VERIFIED_LEGACY_CORE | `EXP-009`–`EXP-012` | Crop/padding/extrusion accepted by `QA-EXP-001`. |
| `EXP-008` | `GDT-001`–`GDT-014` | IMPLEMENTED_UNVERIFIED | `QA-GDT-001` | Native mappings, portable node building, appearance persistence, import reports, API docs, and clean-consumer coverage are implemented. |
| `RNT-001` | `GDT-002` | PARTIALLY_IMPLEMENTED | `GDT-002`, `QA-GDT-001` | Portable import plugin accepted by `QA-RNT-001`; broader import UX remains. |
| `RNT-002` | `GDT-001` | PARTIALLY_IMPLEMENTED | `GDT-001`, `QA-GDT-001` | Portable runtime resource accepted by `QA-RNT-001`; persistence example and docs remain. |
| `RNT-003` | `GDT-003` | PARTIALLY_IMPLEMENTED | `GDT-003`, `QA-GDT-001` | Stateful player core accepted by `QA-RNT-001`; complete track/curve playback remains. |
| `RNT-004` | `GDT-004`, `GDT-005` | PARTIALLY_IMPLEMENTED | `GDT-004`, `GDT-005`, `QA-GDT-001` | Skeleton/Polygon2D/IK core accepted by `QA-RNT-001`; weighted deformation remains. |
| `RNT-005` | `GDT-006`, `GDT-011` | PARTIALLY_IMPLEMENTED | `GDT-006`, `GDT-011`, `QA-GDT-001` | Facing and rule evaluation core accepted by `QA-RNT-001`. |
| `RNT-006` | `GDT-007`, `GDT-009` | PARTIALLY_IMPLEMENTED | `GDT-007`–`GDT-010`, `QA-GDT-001` | Basic events/equipment accepted by `QA-RNT-001`; action-point, collision, and weapon-solver parity remain. |
| `WPN-001`–`WPN-007` | `WPN-001`–`WPN-007` | VERIFIED_LEGACY_CORE | `QA-WPN-001` | Schema, registry, grips, points, dual grips, and hand poses accepted by `QA-WPN-META-001`. |
| Legacy `WPN-008` | `SOL-002`, `SOL-004` | PARTIALLY_IMPLEMENTED | `SOL-001`–`SOL-015`, `WPA-001`–`WPA-015`, `QA-SOL-001`, `QA-WPA-001` | Basic arm/wrist alignment accepted by `QA-WPN-META-001`. The historical task ID is not the master primary-hand drive task. |
| `META-001`–`META-006` | `GMD-001`–`GMD-008`, `MED-001`–`MED-010` | IMPLEMENTED_UNVERIFIED | `QA-GMD-001`, `QA-MED-001` | Metadata inspector plus audio, waveform, lip-sync, scrubbing, and reference-media workflows are implemented; independent timing/synchronization review remains. |

## Newly Planned Work

All master-plan IDs not named as a completed legacy implementation above are
`PLANNED`, except for master tasks explicitly recorded as implementation work
in the ledger. The master plan remains the authoritative per-ID task index; the
ledger adds its required, full task row before each implementation begins. The
Phase 0 QA rows have been added because their dependencies are ready. The
traceability matrix points to this record for the exact legacy/core split rather
than treating a runtime helper as a finished authoring workflow.

## Phase 0 Ownership

| Task ID | Purpose | Status |
|---|---|---|
| `REC-PLAN-001` | Create this reconciliation, add the planned ledger ownership, and create the clean-consumer fixture | IMPLEMENTED_UNVERIFIED |
| `QA-WPN-META-001` | Independently verify legacy weapon and gameplay-metadata work | COMPLETED |
| `QA-GRID-001` | Independently verify legacy facing-grid core | COMPLETED |
| `QA-EXP-001` | Independently verify legacy exporters and artifact opening | COMPLETED |
| `QA-RNT-001` | Independently verify the legacy runtime/import path | COMPLETED |
| `QA-FAC-001` | Review master-facing authoring parity | COMPLETED |
| `QA-RUL-001` | Review master blending/state/rule parity | PLANNED |
| `QA-GDT-001` | Verify the clean-consumer Godot round trip | PLANNED |

## Phase 1 Ownership

| Task ID | Purpose | Status |
|---|---|---|
| `FAC-002` | User-reachable 4/8/16/custom direction-set editor | VERIFIED |
| `FAC-003` | User-reachable selected-cell asset assignment | VERIFIED |
| `FAC-004` | Deterministic filename-based batch placement | VERIFIED |
| `FAC-005` | Selected-cell left/right slot exchange | VERIFIED |
| `FAC-006` | Safe source-to-destination directional cell mirroring | VERIFIED |
| `FAC-007` | Author-selectable hard direction switching | VERIFIED |
| `FAC-008` | Author-selectable optional sprite crossfade | VERIFIED |
| `FAC-009` | Directional deformable-mesh blend authoring and validation | VERIFIED |
| `FAC-010` | Runtime-equivalent continuous direction-scrub preview | VERIFIED |
| `FAC-011` | Missing-cell diagnostics and correction navigation | VERIFIED |
| `FAC-012` | Pixel-mode hard-switch authoring override | VERIFIED |

## Phase 1 Pose and Retargeting Ownership

| Task ID | Purpose | Status |
|---|---|---|
| `POS-001` | Serializable absolute/additive named pose schema | VERIFIED |
| `POS-002` | User-reachable named-pose capture, library serialization, and absolute application | VERIFIED |
| `POS-003` | Explicit bone-pair named-pose mirroring | VERIFIED |
| `POS-004` | Deterministic compatible absolute-pose blending and bound-rig preview | VERIFIED |
| `POS-005` | Additive named-pose composition and capture mode | VERIFIED |
| `POS-006` | Deterministic user-visible saved-pose thumbnails | VERIFIED |
| `POS-007` | Non-destructive sketch-to-pose suggestion workflow | VERIFIED |
| `RET-001` | Serializable semantic skeleton profile contract | VERIFIED |
| `RET-002` | Semantic source-to-target mapping with recoverable diagnostics | VERIFIED |
| `RET-003` | Per-bone proportion compensation | VERIFIED |
| `RET-004` | User-reachable retarget transfer preview | VERIFIED |
| `RET-005` | Deterministic retarget batch processing | VERIFIED |
| `RET-006` | Post-transfer correction layers | VERIFIED |

## Phase 2 Weapon Drive-Mode Ownership

The legacy ledger already used `WPN-008` for a different posing-editor task.
The `WPN-*-DRIVE` task IDs therefore uniquely carry the master-plan drive-mode
work, while the master-plan IDs remain the authority for scope.

| Master-plan ID | Dedicated ledger task | Purpose | Status | Independent verification |
|---|---|---|---|---|
| `WPN-008` | `WPN-008-DRIVE` | Resolve weapon pose from its bound primary hand | IMPLEMENTED_UNVERIFIED | `QA-WPN-001` |
| `WPN-009` | `WPN-009-DRIVE` | Resolve weapon pose from controller transform context | IMPLEMENTED_UNVERIFIED | `QA-WPN-001` |
| `WPN-010` | `WPN-010-DRIVE` | Resolve an authored local socket on a body bone | IMPLEMENTED_UNVERIFIED | `QA-WPN-001` |
| `WPN-011` | `WPN-011-DRIVE` | Resolve a flexible path, normalized progress, and tangent | IMPLEMENTED_UNVERIFIED | `QA-WPN-001` |
| `WPN-012` | `WPN-012-DRIVE` | Resolve a floating world-anchor transform | IMPLEMENTED_UNVERIFIED | `QA-WPN-001` |
| `WPN-013` | `WPN-013-DRIVE` | Resolve a registered custom drive-plugin transform | IMPLEMENTED_UNVERIFIED | `QA-WPN-001` |
| `SOL-001`–`SOL-015` | `SOL-001`–`SOL-015` | Arm and hand solver completion | IMPLEMENTED_UNVERIFIED | `QA-SOL-001` |
| `WPA-001`–`WPA-015` | `WPA-001`–`WPA-015` | Equipment authoring wizard completion | IMPLEMENTED_UNVERIFIED | `QA-WPA-001` |

## Phase 3 Character Creator Ownership

| Master-plan ID | Dedicated ledger task | Purpose | Status | Independent verification |
|---|---|---|---|---|
| `CHR-001`–`CHR-004` | `CHR-001`–`CHR-004` | Schemas, registries, assembly, and conflict repair explanations | IMPLEMENTED_UNVERIFIED | `QA-CHR-001` |
| `CHR-005`–`CHR-008` | `CHR-005`–`CHR-008` | Browsing, palettes, attachment maps, and outfits | IMPLEMENTED_UNVERIFIED | `QA-CHR-001` |
| `CHR-009`–`CHR-012` | `CHR-009`–`CHR-012` | Deterministic randomizer, locks, presets, and unique NPC batches | IMPLEMENTED_UNVERIFIED | `QA-CHR-001` |
| `CHR-013`–`CHR-016` | `CHR-013`–`CHR-016` | Compatible weapons, undo/redo, creator dock, and session restore | IMPLEMENTED_UNVERIFIED | `QA-CHR-001` |

## Phase 4 Gameplay Metadata and Media Ownership

| Master-plan ID | Dedicated ledger task | Purpose | Status | Independent verification |
|---|---|---|---|---|
| `GMD-001`–`GMD-008` | `GMD-001`–`GMD-008` | Frame-accurate gameplay metadata inspection and authoring | IMPLEMENTED_UNVERIFIED | `QA-GMD-001` |
| `MED-001`–`MED-010` | `MED-001`–`MED-010` | Audio, waveform, lip sync, and reference-media workflows | IMPLEMENTED_UNVERIFIED | `QA-MED-001` |

## Phase 5 Advanced Composition Ownership

| Master-plan ID | Dedicated ledger task | Purpose | Status | Independent verification |
|---|---|---|---|---|
| `BLD-001`–`BLD-005` | `BLD-001` | Masked additive blending, sync groups, overlays, and preview | IMPLEMENTED_UNVERIFIED | `QA-RUL-001` |
| `STM-001`–`STM-004` | `STM-001` | Visual graph editing, nested machines, preview, and export | IMPLEMENTED_UNVERIFIED | `QA-RUL-001` |
| `RUL-001`–`RUL-005` | `RUL-001` | Rule graph, time/event actions, cycle protection, and diagnostics | IMPLEMENTED_UNVERIFIED | `QA-RUL-001` |
| `LNK-001`–`LNK-008` | `LNK-001` | Shared-project links, refresh, overrides, conflicts, packages, and previews | IMPLEMENTED_UNVERIFIED | `QA-LNK-001` |

## Phase 6 Export and Godot Consumer Runtime Ownership

| Master-plan ID | Dedicated ledger task | Purpose | Status | Independent verification |
|---|---|---|---|---|
| `EXP-009`–`EXP-012` | `EXP-009` | Batch variants, safe cancellation/progress, artifact validation, and output checks | IMPLEMENTED_UNVERIFIED | `QA-EXP-BATCH-001` |
| `GDT-001`–`GDT-014` | `GDT-001` | Native mapping, portable runtime, import reports, appearance persistence, and API docs | IMPLEMENTED_UNVERIFIED | `QA-GDT-001` |

## Phase 7 Reliability, Accessibility, and Packaging Ownership

| Master-plan ID | Dedicated ledger task | Purpose | Status | Independent verification |
|---|---|---|---|---|
| `REC-001`–`REC-002` | `REC-001` | Recovery browser and interrupted-save recovery | IMPLEMENTED_UNVERIFIED | `QA-PRF-001` |
| `PRF-001`–`PRF-006` | `REC-001` | Profiler, progressive/lazy work, scrub/solver budgets, and stress fixture | IMPLEMENTED_UNVERIFIED | `QA-PRF-001` |
| `ACC-001`–`ACC-004` | `REC-001` | Focus audit, keyboard/controller support, reduced motion, and high contrast | IMPLEMENTED_UNVERIFIED | `QA-PRF-001` |

## Phase 8 Samples, Documentation, and Release Ownership

| Master-plan ID | Dedicated ledger task | Purpose | Status | Independent verification |
|---|---|---|---|---|
| `SMP-001`–`SMP-006` | `SMP-001` | Six representative validated project samples | IMPLEMENTED_UNVERIFIED | `QA-REL-001` |
| `DOCS-001`–`DOCS-004` | `SMP-001` | User, asset, weapon, plugin, and release documentation | IMPLEMENTED_UNVERIFIED | `QA-REL-001` |
| `REL-001`–`REL-004` | `REL-001` | Release notes, known issues, licensing, Windows preset, and preflight | IMPLEMENTED_UNVERIFIED | `QA-REL-001` |

## Closure Criterion

This reconciliation is active until the ledger has a dedicated task row for
every remaining master-plan task. The Phase 0 QA tasks remain independent and
may mark requirements `VERIFIED` only after their own evidence bundles are
accepted.
