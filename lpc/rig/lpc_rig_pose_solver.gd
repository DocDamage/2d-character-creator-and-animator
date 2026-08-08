# LpcRigPoseSolver -- Analytic, direction-local two-bone posing for LPC rigid cutout rigs.
class_name LpcRigPoseSolver
extends RefCounted

const EvaluatorScript = preload("res://lpc/rig/lpc_rig_evaluator.gd")


static func solve_two_bone(adapter: Dictionary, root_id: String, mid_id: String, tip_id: String, target: Variant, options: Dictionary = {}) -> Dictionary:
	var transforms := EvaluatorScript.bone_transforms(adapter, options.get("existing_state", {}))
	if not bool(transforms.get("success", false)): return {"success": false, "errors": transforms.get("errors", [])}
	var current: Dictionary = transforms.get("current", {}); var bones: Dictionary = adapter.get("bones", {})
	if not current.has(root_id) or not current.has(mid_id) or not current.has(tip_id): return {"success": false, "errors": ["IK chain references a missing LPC rig bone."]}
	var root_position := (current[root_id] as Transform2D).origin; var mid_position := (current[mid_id] as Transform2D).origin; var tip_position := (current[tip_id] as Transform2D).origin
	var first_length := maxf(0.001, root_position.distance_to(mid_position)); var second_length := maxf(0.001, mid_position.distance_to(tip_position)); var target_position := _vector(target)
	var distance := root_position.distance_to(target_position); var minimum := absf(first_length - second_length) + 0.0001; var maximum := first_length + second_length - 0.0001
	if distance > maximum + 0.0001 or distance < minimum - 0.0001:
		return {"success": false, "errors": ["Weapon/hand target is outside the authored two-bone reach."], "reachable": false, "distance": distance, "minimum_reach": minimum, "maximum_reach": maximum}
	distance = clampf(distance, minimum, maximum)
	var direction := (target_position - root_position).angle()
	var root_angle := acos(clampf((first_length * first_length + distance * distance - second_length * second_length) / (2.0 * first_length * distance), -1.0, 1.0))
	var mid_angle := acos(clampf((first_length * first_length + second_length * second_length - distance * distance) / (2.0 * first_length * second_length), -1.0, 1.0))
	var sign := 1.0 if bool(options.get("bend_positive", true)) else -1.0
	var desired_root_global := direction + root_angle * sign
	var desired_mid_global := desired_root_global + (PI - mid_angle) * sign
	var root_parent_rotation := _parent_rotation(current, bones, root_id); var root_local := rad_to_deg(desired_root_global - root_parent_rotation); var mid_local := rad_to_deg(desired_mid_global - desired_root_global)
	var hand_rotation := float(options.get("hand_rotation_degrees", rad_to_deg(desired_mid_global)))
	var state := {
		root_id: {"rotation_degrees": root_local}, mid_id: {"rotation_degrees": mid_local},
		tip_id: {"rotation_degrees": hand_rotation - rad_to_deg(desired_mid_global)},
	}
	return {"success": true, "errors": [], "reachable": true, "bone_state": state, "target": _serialize(target_position), "chain": [root_id, mid_id, tip_id], "grip_gap": 0.0}


static func solve_weapon_hands(adapter: Dictionary, weapon_anchor_targets: Dictionary, existing_state: Dictionary = {}) -> Dictionary:
	var anchors := adapter.get("anchors", {}) as Dictionary; var output: Dictionary = {}; var errors: Array[String] = []
	for anchor_id in weapon_anchor_targets:
		var anchor: Dictionary = anchors.get(str(anchor_id), {})
		var hand_id := str(anchor.get("bone_id", "")); var chain := _chain_for_hand(adapter.get("bones", {}) as Dictionary, hand_id)
		if chain.size() != 3: errors.append("Anchor '%s' has no valid two-bone hand chain." % anchor_id); continue
		var solved := solve_two_bone(adapter, str(chain[0]), str(chain[1]), hand_id, weapon_anchor_targets[anchor_id], {"existing_state": existing_state, "bend_positive": not str(anchor_id).contains("right")})
		if not bool(solved.get("success", false)): errors.append_array(solved.get("errors", [])); continue
		for bone_id in (solved.get("bone_state", {}) as Dictionary): output[bone_id] = solved.bone_state[bone_id]
	return {"success": errors.is_empty(), "errors": errors, "bone_state": output, "anchor_count": weapon_anchor_targets.size()}


static func _chain_for_hand(bones: Dictionary, hand_id: String) -> Array:
	if not bones.has(hand_id): return []
	var lower := str((bones[hand_id] as Dictionary).get("parent_id", "")); if lower.is_empty() or not bones.has(lower): return []
	var upper := str((bones[lower] as Dictionary).get("parent_id", "")); return [upper, lower, hand_id] if not upper.is_empty() and bones.has(upper) else []
static func _parent_rotation(current: Dictionary, bones: Dictionary, bone_id: String) -> float:
	var parent_id := str((bones.get(bone_id, {}) as Dictionary).get("parent_id", "")); return (current[parent_id] as Transform2D).get_rotation() if not parent_id.is_empty() and current.has(parent_id) else 0.0
static func _vector(value: Variant) -> Vector2:
	if value is Vector2: return value
	if value is Array and (value as Array).size() >= 2: return Vector2(float(value[0]), float(value[1]))
	if value is Dictionary: return Vector2(float(value.get("x", value.get("position_x", 0.0))), float(value.get("y", value.get("position_y", 0.0))))
	return Vector2.ZERO
static func _serialize(value: Vector2) -> Array: return [value.x, value.y]
