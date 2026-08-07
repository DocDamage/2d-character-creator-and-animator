# LpcSheetLayout -- Versioned, data-driven LPC sheet layout adapters and frame refs.
class_name LpcSheetLayout
extends RefCounted

const STANDARD_LAYOUT_ID := "lpc_standard_v1"
const STANDARD_DIRECTIONS := ["up", "left", "down", "right"]


static func standard_adapter() -> Dictionary:
	return {
		"layout_id": STANDARD_LAYOUT_ID,
		"version": "1.0.0",
		"frame_size": [64, 64],
		"frame_columns": 13,
		"direction_order": STANDARD_DIRECTIONS.duplicate(),
		"default_supported_animations": ["spellcast", "thrust", "walk", "slash", "shoot", "hurt"],
		"animation_aliases": {"idle": "walk"},
		"animations": {
			"spellcast": {"row_start": 0, "cycle": [0, 1, 2, 3, 4, 5, 6, 7], "frame_duration": 0.1},
			"thrust": {"row_start": 4, "cycle": [0, 1, 2, 3, 4, 5, 6, 7], "frame_duration": 0.1},
			"walk": {"row_start": 8, "cycle": [0, 1, 2, 3, 4, 5, 6, 7, 8], "frame_duration": 0.1},
			"slash": {"row_start": 12, "cycle": [0, 1, 2, 3, 4, 5], "frame_duration": 0.1},
			"shoot": {"row_start": 16, "cycle": [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12], "frame_duration": 0.1},
			"hurt": {"row_start": 20, "cycle": [0, 1, 2, 3, 4, 5], "frame_duration": 0.1},
		},
		"oversize_frames": {},
		"custom_mappings": {},
	}


static func validate(layout: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	if str(layout.get("layout_id", "")).is_empty(): errors.append("Layout ID is required.")
	if str(layout.get("version", "")).is_empty(): errors.append("Layout version is required.")
	var size: Array = layout.get("frame_size", [])
	if size.size() != 2 or int(size[0]) <= 0 or int(size[1]) <= 0:
		errors.append("Layout frame_size must contain two positive values.")
	if int(layout.get("frame_columns", 0)) <= 0: errors.append("Layout frame_columns must be positive.")
	var directions: Array = layout.get("direction_order", [])
	if directions.is_empty(): errors.append("Layout direction_order cannot be empty.")
	var animations: Dictionary = layout.get("animations", {})
	if animations.is_empty(): errors.append("Layout has no animation mappings.")
	for animation_id in animations:
		var animation: Dictionary = animations[animation_id]
		if int(animation.get("row_start", -1)) < 0: errors.append("%s has invalid row_start." % animation_id)
		var cycle: Array = animation.get("cycle", [])
		if cycle.is_empty(): errors.append("%s has no source-frame cycle." % animation_id)
		for column in cycle:
			if int(column) < 0 or int(column) >= int(layout.get("frame_columns", 0)):
				errors.append("%s has out-of-range cycle column %s." % [animation_id, column])
	return errors


static func normalize_supported_animations(asset: Dictionary, layout: Dictionary) -> Array[String]:
	var explicit: Array = asset.get("supported_animations", [])
	if explicit.is_empty(): explicit = layout.get("default_supported_animations", [])
	var result: Array[String] = []
	for animation_id in explicit:
		var resolved := resolve_animation_id(str(animation_id), layout)
		if not resolved.is_empty() and resolved not in result: result.append(resolved)
	return result


static func frame_ref(asset: Dictionary, layout: Dictionary, animation_id: String, direction_id: String, logical_frame_index: int) -> Dictionary:
	var resolved := resolve_animation_id(animation_id, layout)
	var errors := validate(layout)
	if not errors.is_empty() or resolved.is_empty():
		return {"success": false, "errors": errors + ["Unknown animation '%s'." % animation_id]}
	var directions: Array = layout.get("direction_order", [])
	var direction_index := directions.find(direction_id)
	if direction_index < 0:
		return {"success": false, "errors": ["Direction '%s' is not supported by this layout." % direction_id]}
	var animation: Dictionary = (layout.get("animations", {}) as Dictionary)[resolved]
	var cycle: Array = animation.get("cycle", [])
	if logical_frame_index < 0 or logical_frame_index >= cycle.size():
		return {"success": false, "errors": ["Frame index is outside the '%s' cycle." % resolved]}
	var frame_size: Array = layout.get("frame_size", [64, 64])
	var column := int(cycle[logical_frame_index])
	var row := int(animation.get("row_start", 0)) + direction_index
	return {
		"success": true,
		"source_asset_id": str(asset.get("asset_id", "")),
		"source_hash": str(asset.get("source_sha256", "")),
		"animation_id": resolved,
		"direction_id": direction_id,
		"logical_frame_index": logical_frame_index,
		"source_cycle_index": column,
		"source_rect": [column * int(frame_size[0]), row * int(frame_size[1]), int(frame_size[0]), int(frame_size[1])],
		"logical_origin": [0, 0],
		"oversize_offset": [0, 0],
		"frame_duration": float(animation.get("frame_duration", 0.1)),
		"topology_group_id": str(asset.get("topology_group_id", "")),
		"layer_order_context": (asset.get("z_order", {}) as Dictionary).duplicate(true),
		"errors": [],
	}


static func resolve_animation_id(animation_id: String, layout: Dictionary) -> String:
	var id := animation_id.strip_edges()
	var aliases: Dictionary = layout.get("animation_aliases", {})
	if aliases.has(id): id = str(aliases[id])
	return id if (layout.get("animations", {}) as Dictionary).has(id) else ""
