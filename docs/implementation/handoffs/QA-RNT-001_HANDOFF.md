# QA-RNT-001 Handoff — Verify legacy runtime/import behavior

## Thread Identity

- Task ID: QA-RNT-001
- Thread type: VERIFICATION
- Status: COMPLETED
- Date: 2026-08-05

## Accepted Behavior

- The distributable addon can be copied into a new Godot project with no
  `runtime_plugin/`, `facing/`, or `animation/` authoring paths.
- Enabling the addon in that project's `project.godot` starts the editor and
  imports a `.chrproj` fixture into a portable runtime resource.
- Generated `.tres` and `.tscn` artifacts load in the same clean project and
  exercise automatic state initialization, facing, skeleton/IK, state/rule and
  timeline events, polygon creation, and equipment swaps.

## Repair Closed During Verification

The first editor startup exposed an invalid absolute `plugin.cfg` script path:
Godot concatenated it with the addon directory. The manifest now uses the
required relative `script="plugin.gd"` value. The clean editor import test
passes after the repair.

## Automated Results

- Full Godot suite: `451 PASS, 0 FAIL`.
- Focused error scan: no matching `ERROR:`, `SCRIPT ERROR:`, loader, IK, or
  clean-consumer failures.
- LOC, stub, and evidence-bundle checks pass.

## Remaining Scope

This closes the legacy `RNT-001` through `RNT-006` requirements only. The
authoritative master-plan `GDT-*` tasks still own full track/curve playback,
weighted deformation, action points, collision, weapon/grip solving, baked
fallback, debug views, persistence examples, and API documentation.
