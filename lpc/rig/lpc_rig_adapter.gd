# LpcRigAdapter -- Versioned direction-specific cutout-rig schema and registry helpers.
class_name LpcRigAdapter
extends RefCounted

const SCHEMA_VERSION := "1.0.0"
const STRATEGIES := ["RIGID_CUTOUT", "WEIGHTED_MESH", "FRAME_SWAP", "HIDDEN"]


static func standard_template(body_family_id: String, direction_id: String, options: Dictionary = {}) -> Dictionary:
	var adapter_id := str(options.get("adapter_id", "lpc_%s_%s_rigid_v1" % [body_family_id, direction_id]))
	return {
		"adapter_id": adapter_id, "adapter_version": "1.0.0", "body_family_id": body_family_id,
		"direction_id": direction_id, "reference_animation_id": str(options.get("reference_animation_id", "walk")),
		"reference_logical_frame": int(options.get("reference_logical_frame", 0)),
		"bones": _standard_bones(), "pieces": _standard_pieces(), "anchors": _standard_anchors(),
		"attachment_slots": _standard_anchors(), "z_groups": {"back": -20, "middle": 0, "front": 20}, "layer_strategies": {},
		"permitted_layer_order_overrides": [], "clothing_transfer_mapping": {}, "chain_definitions": {},
		"overlap_padding": 1, "gap_patch_regions": [], "mirror_policy": {"allowed": false, "editable": true},
		"source_signatures": [], "validation_fixtures": [], "manual_setup": bool(options.get("manual_setup", true)),
	}


static func create_instance(template: Dictionary, source_context: Dictionary, pieces: Array, options: Dictionary = {}) -> Dictionary:
	var adapter := template.duplicate(true)
	adapter["rig_schema_version"] = SCHEMA_VERSION
	adapter["instance_id"] = str(options.get("instance_id", "rig_" + str(Time.get_ticks_usec())))
	adapter["adapter_id"] = str(adapter.get("adapter_id", "manual_lpc_adapter"))
	adapter["adapter_version"] = str(adapter.get("adapter_version", "1.0.0"))
	adapter["source_binding"] = {
		"source_instance_id": str(source_context.get("source_instance_id", "")),
		"source_asset_id": str(source_context.get("source_asset_id", "")),
		"source_hash": str(source_context.get("source_hash", source_context.get("source_asset_sha256", ""))),
		"source_frame_hash": str(source_context.get("source_frame_hash", "")),
		"source_frame_reference": (source_context.get("source_frame_reference", {}) as Dictionary).duplicate(true),
		"mask_signature": str(options.get("mask_signature", "")),
	}
	adapter["pieces"] = pieces.duplicate(true)
	adapter["bone_ids"] = bone_ids(adapter)
	adapter["enabled"] = true
	adapter["created_at"] = Time.get_unix_time_from_system()
	return adapter


static func validate(adapter: Dictionary, derivative_ids: Dictionary = {}) -> Array[String]:
	var errors: Array[String] = []
	for key in ["rig_schema_version", "instance_id", "adapter_id", "body_family_id", "direction_id", "source_binding", "bones", "pieces", "anchors", "z_groups"]:
		if not adapter.has(key): errors.append("LPC rig adapter is missing '%s'." % key)
	if str(adapter.get("rig_schema_version", "")) != SCHEMA_VERSION: errors.append("Unsupported LPC rig schema '%s'." % adapter.get("rig_schema_version", ""))
	if str(adapter.get("instance_id", "")).is_empty(): errors.append("LPC rig adapter needs a durable instance ID.")
	if str(adapter.get("body_family_id", "")).is_empty() or str(adapter.get("direction_id", "")).is_empty(): errors.append("LPC rig adapter must declare a body family and explicit direction.")
	var binding: Dictionary = adapter.get("source_binding", {})
	for key in ["source_instance_id", "source_asset_id", "source_hash", "source_frame_reference"]:
		if not binding.has(key) or str(binding.get(key, "")).is_empty() and key != "source_frame_reference": errors.append("LPC rig adapter source binding is missing '%s'." % key)
	var bones: Dictionary = adapter.get("bones", {})
	if bones.is_empty(): errors.append("LPC rig adapter needs at least one bone.")
	for bone_id in bones:
		var bone: Dictionary = bones[bone_id] if bones[bone_id] is Dictionary else {}
		if str(bone.get("bone_id", bone_id)).is_empty(): errors.append("LPC rig adapter has an unnamed bone.")
		var parent_id := str(bone.get("parent_id", ""))
		if not parent_id.is_empty() and not bones.has(parent_id): errors.append("Bone '%s' references missing parent '%s'." % [bone_id, parent_id])
	if not _acyclic(bones): errors.append("LPC rig adapter bone hierarchy contains a cycle.")
	var seen: Dictionary = {}
	for raw_piece in adapter.get("pieces", []):
		if not raw_piece is Dictionary: errors.append("LPC rig adapter has an invalid piece."); continue
		var piece: Dictionary = raw_piece
		var piece_id := str(piece.get("piece_id", ""))
		if piece_id.is_empty() or seen.has(piece_id): errors.append("LPC rig adapter has a missing or duplicate piece ID.")
		seen[piece_id] = true
		if not bones.has(str(piece.get("bone_id", ""))): errors.append("Piece '%s' references a missing bone." % piece_id)
		var mask: Variant = piece.get("mask_rect", [])
		if not mask is Array or (mask as Array).size() < 4 or int(mask[2]) <= 0 or int(mask[3]) <= 0: errors.append("Piece '%s' needs a non-empty source mask rectangle." % piece_id)
		if not (adapter.get("z_groups", {}) as Dictionary).has(str(piece.get("z_group", "middle"))): errors.append("Piece '%s' references an undeclared z group." % piece_id)
		var strategy := str(piece.get("strategy", "RIGID_CUTOUT")).to_upper()
		if strategy not in STRATEGIES: errors.append("Piece '%s' has unsupported strategy '%s'." % [piece_id, strategy])
		var derivative_id := str(piece.get("derivative_id", ""))
		if strategy != "HIDDEN" and derivative_id.is_empty(): errors.append("Piece '%s' has no project-owned derivative." % piece_id)
		if not derivative_ids.is_empty() and not derivative_id.is_empty() and not derivative_ids.has(derivative_id): errors.append("Piece '%s' references a missing derivative." % piece_id)
	for anchor_id in (adapter.get("anchors", {}) as Dictionary):
		var anchor: Dictionary = (adapter.get("anchors", {}) as Dictionary).get(anchor_id, {})
		if not bones.has(str(anchor.get("bone_id", ""))): errors.append("Anchor '%s' references a missing rig bone." % anchor_id)
		var point: Variant = anchor.get("position", [])
		if not point is Array or (point as Array).size() < 2: errors.append("Anchor '%s' needs a rest position." % anchor_id)
	return errors


static func find_for_layer(profile: Dictionary, instance_id: String, direction_id: String = "") -> Dictionary:
	var fallback: Dictionary = {}
	for raw_adapter in profile.get("rig_adapters", []):
		if not raw_adapter is Dictionary: continue
		var adapter: Dictionary = raw_adapter
		if not bool(adapter.get("enabled", true)): continue
		var binding: Dictionary = adapter.get("source_binding", {})
		if str(binding.get("source_instance_id", "")) != instance_id: continue
		if direction_id.is_empty() or str(adapter.get("direction_id", "")) == direction_id: return adapter.duplicate(true)
		if fallback.is_empty(): fallback = adapter.duplicate(true)
	return fallback


static func known_target(profile: Dictionary, target_id: String) -> bool:
	for raw_adapter in profile.get("rig_adapters", []):
		if not raw_adapter is Dictionary: continue
		var adapter: Dictionary = raw_adapter
		var instance_id := str(adapter.get("instance_id", ""))
		if target_id == instance_id or target_id == str(adapter.get("adapter_id", "")): return true
		for bone_id in bone_ids(adapter):
			if target_id == str(bone_id) or target_id == instance_id + ":" + str(bone_id): return true
	return false


static func bone_ids(adapter: Dictionary) -> Array:
	var result: Array = []
	for bone_id in (adapter.get("bones", {}) as Dictionary): result.append(str(bone_id))
	result.sort()
	return result


static func derivative_id_map(profile: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for raw in profile.get("derivative_references", []):
		if raw is Dictionary: result[str((raw as Dictionary).get("derivative_id", ""))] = true
	return result


static func _standard_bones() -> Dictionary:
	return {
		"root": _bone("root", "", [32, 48], 0.0, 1.0), "torso": _bone("torso", "root", [0, -12], 0.0, 18.0),
		"head": _bone("head", "torso", [0, -18], 0.0, 10.0),
		"arm_left_upper": _bone("arm_left_upper", "torso", [-12, -10], 0.0, 12.0),
		"arm_left_lower": _bone("arm_left_lower", "arm_left_upper", [-8, 9], 0.0, 11.0),
		"hand_left": _bone("hand_left", "arm_left_lower", [-7, 8], 0.0, 4.0),
		"arm_right_upper": _bone("arm_right_upper", "torso", [12, -10], 0.0, 12.0),
		"arm_right_lower": _bone("arm_right_lower", "arm_right_upper", [8, 9], 0.0, 11.0),
		"hand_right": _bone("hand_right", "arm_right_lower", [7, 8], 0.0, 4.0),
	}


static func _bone(bone_id: String, parent_id: String, position: Array, rotation: float, length: float) -> Dictionary:
	return {"bone_id": bone_id, "parent_id": parent_id, "rest_position": position, "rest_rotation_degrees": rotation, "length": length}


static func _standard_pieces() -> Array:
	# These partitions deliberately cover the full reference frame; manual setup can replace them with anatomy-aware masks.
	return [
		{"piece_id": "head", "bone_id": "head", "mask_rect": [0, 0, 64, 20], "pivot": [32, 18], "z_group": "front", "strategy": "RIGID_CUTOUT"},
		{"piece_id": "torso", "bone_id": "torso", "mask_rect": [0, 20, 64, 20], "pivot": [32, 36], "z_group": "middle", "strategy": "RIGID_CUTOUT"},
		{"piece_id": "left_lower", "bone_id": "hand_left", "mask_rect": [0, 40, 32, 24], "pivot": [5, 55], "z_group": "front", "strategy": "RIGID_CUTOUT"},
		{"piece_id": "right_lower", "bone_id": "hand_right", "mask_rect": [32, 40, 32, 24], "pivot": [59, 55], "z_group": "front", "strategy": "RIGID_CUTOUT"},
	]


static func _standard_anchors() -> Dictionary:
	return {"hand_left": {"bone_id": "hand_left", "position": [16, 56]}, "hand_right": {"bone_id": "hand_right", "position": [48, 56]}, "weapon": {"bone_id": "hand_right", "position": [48, 56]}}


static func _acyclic(bones: Dictionary) -> bool:
	for bone_id in bones:
		var seen: Dictionary = {}; var current := str(bone_id)
		while not current.is_empty():
			if seen.has(current): return false
			seen[current] = true
			var bone: Dictionary = bones.get(current, {})
			current = str(bone.get("parent_id", ""))
	return true
