# Runtime Plugin API

The generated addon is self-contained under `addons/modular_character_runtime`.
Consumer projects use `CharacterPlayer2D` from generated scenes or load a
`CharacterRuntimeData` resource directly.

## Loading and playback

Call `load_runtime_data(resource)` or `load_package(package)` and then use
`set_parameter`, `trigger`, and `set_facing_direction`. The node emits
`state_changed`, `animation_event`, and `equipment_changed`.

## Appearance and equipment

`set_appearance`, `save_appearance`, and `restore_appearance` persist a
palette/parts/equipment dictionary. Use `equip` and `unequip` for a single
slot. `resolve_grip_target(weapon_id, grip_id)` returns a safe bone target.

## Debug and consumer checks

`set_debug_views_enabled` and `get_debug_snapshot` expose state, facing,
generated runtime nodes, sampled tracks, collision/marker counts, equipment,
and baked-fallback metadata. `ChrprojImporter.import_data` returns an import
report with missing-section warnings; consumers can block or display them.
