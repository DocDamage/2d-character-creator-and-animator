# Directional Cell Asset Assignment Evidence

## Task ID

`FAC-003`

## Status

IMPLEMENTED_UNVERIFIED. This task makes the selected cell in the reachable
Facing Grid Directions panel accept, replace, and clear an asset ID.
Independent end-to-end authoring acceptance remains `QA-FAC-001`.

## Evidence

- The panel shows the selected direction, current asset ID, and enabled
  assign/clear controls.
- `assign_asset_to_selected` rejects empty IDs, retains existing cell data,
  and writes the selected cell through `FacingGridDefinition.set_cell`.
- `clear_asset_from_selected` removes only the selected assigned cell, so it
  becomes a real missing direction rather than an empty placeholder.
- `tests/integration/test_facing_direction_editor.gd` verifies assignment,
  replacement, clearing, invalid input, cell status, and persisted round trip.

## Scope Boundary

This task accepts asset IDs entered through the user-facing panel or a caller
of its public assignment method. Filename placement, folder batch placement,
slot exchange, mirroring, preview, diagnostics, and pixel controls remain
separate master-plan tasks.
