# Project Completion Implementation Plan

> **Status:** Implementation and non-release verification complete; `QA-REL-001` clean-machine release acceptance remains.
>
> **Current verification:** Godot 4.7.1; 496 automated assertions pass, with LOC/stub/evidence scans passing.
>
> **Purpose:** Complete the Modular 2D Character Studio from its implemented foundation through a shippable, independently verified release.

---

## 1. Planning Rule: Reconcile the Two Milestone Numberings First

The master plan and task ledger currently use different milestone numbering after Milestone 9. The master plan is authoritative for feature scope; the ledger records implemented work under a later revised sequence. Before starting new feature work, create a reconciliation record that:

- Maps ledger `GRID-*`, `EXP-*`, and `RNT-*` work to master-plan `FAC-*`, `BLD/STM/RUL-*`, `EXP-*`, and `GDT-*` requirements.
- Marks each requirement as `VERIFIED`, `IMPLEMENTED_UNVERIFIED`, `PLANNED`, or `PARTIALLY_IMPLEMENTED` without inflating completion.
- Splits master tasks where only their runtime core exists and their authoring UI, validation, or clean-consumer acceptance criteria remain.
- Adds a dedicated QA task for every implemented group before its milestone is closed.

**Exit gate:** the task ledger, traceability matrix, and master plan all identify one unambiguous task ID for every remaining requirement.

---

## 2. Phase 0 — Stabilize and Independently Verify the Existing Foundation

### Scope

- Run independent QA for the 34 requirements currently marked `IMPLEMENTED_UNVERIFIED`.
- Verify all existing workflows against Godot 4.7.1, including save/reopen, import/export, and error recovery.
- Add regression tests for fixed transform snapping and selective transform inheritance.
- Establish a clean-consumer-project fixture used by all later export/runtime verification.

### Required task groups

- Existing verification: `QA-WPN-META-001`.
- New verification: `QA-GRID-001`, `QA-EXP-001`, `QA-RNT-001`.
- Master-plan parity review: `QA-FAC-001`, `QA-RUL-001`, `QA-GDT-001`.

### Exit gate

- Every existing requirement is either `VERIFIED` or has a named repair task.
- The full suite, LOC checker, stub scanner, and evidence checker pass in CI and locally.
- Clean consumer fixture loads a generated `.tres`/`.tscn` package without authoring-tool dependencies.

---

## 3. Phase 1 — Finish Facing-Grid Authoring and Pose/Retargeting Workflows

### Scope

Complete the authoring features that sit between the existing rig/deformation data and higher-level character/weapon work.

### Required task groups

| Area | Master-plan IDs | Deliverables |
|---|---|---|
| Facing-grid authoring | `FAC-002` through `FAC-012` | Direction-set editor, cell assignment, filename/folder placement, preview, slot swaps, mirroring, diagnostics, pixel-mode controls, correction offsets. |
| Pose authoring | `POS-001` through `POS-007` | Pose schema, save/apply/mirror, blend/additive behavior, thumbnails, sketch assistance. |
| Retargeting | `RET-001` through `RET-006` | Skeleton profiles, bone mapping, proportion compensation, interactive preview, batch retargeting, correction layers. |
| Verification | `QA-FAC-001`, `QA-POS-001` | Visual and numerical authoring-to-runtime parity tests. |

### Exit gate

- A user can author a complete 4- and 8-way pose set, retarget it to a compatible rig, save/reopen it, and export it.
- Missing directional cells and unsupported retarget mappings produce recoverable diagnostics.

---

## 4. Phase 2 — Complete Weapons, Arm Solving, and Equipment Authoring

### Scope

Build out the remaining data-driven weapon workflows beyond the current schema, basic pose solver, and runtime equipment swap.

### Required task groups

| Area | Master-plan IDs | Deliverables |
|---|---|---|
| Weapon data and drive modes | `WPN-008` through `WPN-013` | Primary-hand, controller, body-socket, path, world, and custom-plugin drive modes. |
| Arm and hand solver | `SOL-001` through `SOL-015` | Shoulder allowance, poles, wrist orientation, two-hand grips, limits, diagnostics, pixel mode, overlays, instrumentation. |
| Weapon wizard | `WPA-001` through `WPA-015` | All-body/direction/coverage previews, reachability reports, dual-wield/shield/bow/flexible workflows, holster/draw/sheath. |
| Verification | `QA-WPN-001`, `QA-SOL-001`, `QA-WPA-001` | Twenty-weapon acceptance matrix and visual/numerical solver checks. |

### Exit gate

- Twenty representative weapons equip, animate, switch direction, and export with no visible grip gap or invalid joint pose.
- Unsupported or unreachable grips report a precise, actionable diagnostic instead of silently producing a bad pose.

---

## 5. Phase 3 — Deliver the Character Creator

### Scope

Turn existing character data modules into a complete, accessible authoring workspace.

### Required task groups

- `CHR-001` through `CHR-016`: part/body schemas, slot and part registries, assembly, compatibility/conflict explanation, browsing, palettes, maps, outfits, deterministic randomization, locks, presets, NPC batches, weapon integration, undo/redo.
- `QA-CHR-001`: generate and validate at least 100 distinct characters.

### Exit gate

- Users can browse parts, assemble a compatible character, resolve a conflict, apply palette changes, save a preset, equip a compatible weapon, and undo/redo every change.
- The deterministic randomizer can reproduce a seeded 100-character batch with no invalid assembly.

---

## 6. Phase 4 — Complete Gameplay Metadata, Audio, and Reference Media

### Scope

Finish authoring/runtime parity for gameplay timing, sound, lip sync, and animation reference material.

### Required task groups

| Area | Master-plan IDs | Deliverables |
|---|---|---|
| Gameplay metadata | `GMD-001` through `GMD-008` | Complete action/event/variable/hitbox/hurtbox data, debug visualization, and deterministic runtime delivery. |
| Audio and lip sync | `MED-001` through `MED-006` | Audio import, waveform cache, sound tracks, scrubbing, visemes, lip-sync import. |
| Reference media | `MED-007` through `MED-010` | Video, GIF, image-sequence references; synchronized playhead; export exclusion; missing-reference repair. |
| Verification | `QA-GMD-001`, `QA-MED-001` | Frame-accurate runtime timing and reference synchronization checks. |

### Exit gate

- Events, hitboxes, action points, sounds, and visemes have matching authoring and runtime timing.
- Reference media can be offset, scrubbed, hidden from output, recovered when missing, and never leaks into baked exports.

---

## 7. Phase 5 — Advanced Animation Blending, State Machines, Rules, and Multi-Project Workflows

### Scope

Extend the current state/rule runtime core into complete authoring and production composition systems, then support reusable linked projects.

### Required task groups

| Area | Master-plan IDs | Deliverables |
|---|---|---|
| Blending | `BLD-001` through `BLD-005` | Additive layers, body masks, upper/lower separation, sync groups, weapon overlays, previews. |
| State machines | `STM-001` through `STM-004` | Visual editor, transitions, nested machines, preview controls, export. |
| Rules | `RUL-001` through `RUL-005` | Graph editor, time windows/events, actions, cycle protection, diagnostics, deterministic runtime parity. |
| Linked projects | `LNK-001` through `LNK-008` | Shared rigs/characters/accessories, refresh, local overrides, conflicts, packaging, multi-character preview. |
| Verification | `QA-RUL-001`, `QA-LNK-001` | Determinism, cyclic-rule safety, broken-link recovery, and merge tests. |

### Exit gate

- Nested state machines and masked/additive blends preview identically after runtime export.
- Linked-project changes refresh safely; broken dependencies and merge conflicts are recoverable without data loss.

---

## 8. Phase 6 — Finish Export and the Godot Consumer Runtime

### Scope

Expand the validated base exporters and `CharacterPlayer2D` into full-fidelity runtime parity and release-ready consumer support.

### Required task groups

| Area | Master-plan IDs | Deliverables |
|---|---|---|
| Export engine | `EXP-009` through `EXP-012` | Batch character/weapon variants, cancellation/progress, artifact validator, output-opening verification. |
| Godot export mappings | `GDT-001` through `GDT-014` | AnimationLibrary/AnimationPlayer/AnimationTree data, weighted Polygon2D deformation, Sprite2D, Marker2D, Area2D shapes, weapon/appearance resources, import reports, API docs. |
| Runtime parity | `GDT-003` through `GDT-011` | Tracks/curves, constraints/deformation, facing, action points, collision, weapons, grip solver, rules, baked fallback, debug views. |
| Consumer verification | `GDT-012` through `GDT-014`, `QA-EXP-001`, `QA-GDT-001` | Appearance persistence, clean sample project, API documentation, full clean-project round trip. |

### Exit gate

- A brand-new Godot project with only the runtime plugin imports generated content, plays clips, blends states, swaps equipment, receives events, shows debug hitboxes, and saves/reloads appearance.
- All requested image, GIF, MP4, and WebM artifacts open successfully; batch/cancel/progress behavior is verified.

---

## 9. Phase 7 — Recovery, Performance, Accessibility, Security, and Packaging

### Scope

Make the finished feature set reliable at production scale and usable through keyboard, controller, and assistive-friendly UI paths.

### Required task groups

| Area | Master-plan IDs | Deliverables |
|---|---|---|
| Recovery | `REC-001`, `REC-002` | Recovery browser and interrupted-save verification. |
| Performance | `PRF-001` through `PRF-006` | Profiler, progressive loading, lazy thumbnails, scrub/solver optimization, large-project stress suite. |
| Accessibility | `ACC-001` through `ACC-004` | Keyboard/controller completion, reduced motion/contrast, focus/label audit. |
| Security and licensing | Master-plan §20.3–20.4 | Path-traversal/media validation, plugin failure isolation, encoder/license audit, attribution updates. |
| Verification | `QA-PRF-001` | Recovery, scale, performance, and accessibility gate. |

### Exit gate

- The documented large-project targets are met or have approved, measured exceptions.
- Interrupted saves recover safely, all core workflows work by keyboard/controller, and security/licensing audits pass.

---

## 10. Phase 8 — Samples, Documentation, and Release

### Scope

Ship a reproducible release with representative assets, complete documentation, licensing, and clean-machine evidence.

### Required task groups

- Samples: `SMP-001` through `SMP-006`.
- Documentation: `DOCS-001` through `DOCS-004`.
- Release: `REL-001` through `REL-004`.
- Final verification: `QA-REL-001`.

### Exit gate

- Humanoid, pixel, deformable, 100-character, 20-weapon, and animation/gameplay samples are included and validated.
- User, asset-authoring, weapon-authoring, and plugin API manuals match current behavior.
- Windows package, clean-machine smoke test, release notes, known issues, licensing, and final independent audit are complete.

---

## 11. Delivery Discipline for Every Phase

For every implementation task:

1. Add or update a ledger row before work starts.
2. Implement a user-reachable workflow, not only a data model.
3. Add focused automated tests and include them in `tests/test_runner.tscn`.
4. Run the full suite plus LOC, stub, and evidence checks.
5. Create a complete evidence bundle and handoff.
6. Update traceability to `IMPLEMENTED_UNVERIFIED`.
7. Run a separate QA task before changing the status to `VERIFIED`.

No phase closes until its exit gate and the master-plan milestone gate rules are satisfied.
