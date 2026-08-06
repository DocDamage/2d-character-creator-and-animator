# Weapon and Gameplay-Metadata Verification Evidence

## Task ID

`QA-WPN-META-001`

## Status

VERIFIED. The legacy weapon/pose and gameplay-metadata requirements have been
accepted through a combined public-API workflow. The broader master-plan weapon
drive modes, solver, wizard, metadata visualization, and media tooling remain
separately tracked.

## Evidence

- `tests/integration/test_weapon_metadata_acceptance.gd` builds and validates a
  weapon with action points, sockets, primary/secondary grips, interaction
  family registration, asset/profile registration, and reusable left/right
  hand poses.
- It applies body, direction, and animation offsets, solves both arm chains to
  their transformed grips, measures each final hand position, and verifies the
  incompatible-body diagnostic path.
- It exercises interpolated action points; hitbox and hurtbox tracks; event,
  audio, viseme, and typed script-parameter tracks; tags and variables; and
  TrackRegistry restoration for all specialized track types.
- The full suite reports `454 PASS, 0 FAIL` with no engine, script, warning,
  loader, or clean-consumer diagnostics.
