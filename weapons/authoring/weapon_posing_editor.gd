# WeaponPosingEditor -- Weapon workspace model for transforms, bindings, previews, and solve.
class_name WeaponPosingEditor
extends RefCounted

signal preview_changed(preview: Dictionary)
signal pose_changed()

var weapon = null
var pose_profile = null
var body_type_id: String = ""
var direction_id: String = ""
var animation_id: String = ""
var solver_options: Dictionary = {}
var last_solver_result: Dictionary = {}


func _init(p_weapon = null, p_profile = null) -> void:
	weapon = p_weapon
	pose_profile = p_profile


func set_preview_context(p_body_type_id: String, p_direction_id: String = "", p_animation_id: String = "") -> Dictionary:
	body_type_id = p_body_type_id
	direction_id = p_direction_id
	animation_id = p_animation_id
	return get_preview()


func set_weapon_transform(position: Vector2, rotation: float) -> bool:
	if pose_profile == null:
		return false
	pose_profile.base_position = position
	pose_profile.base_rotation = rotation
	pose_changed.emit()
	preview_changed.emit(get_preview())
	return true


func apply_transform_delta(position_delta: Vector2, rotation_delta: float) -> bool:
	if pose_profile == null:
		return false
	return set_weapon_transform(pose_profile.base_position + position_delta, pose_profile.base_rotation + rotation_delta)


func bind_hand_to_grip(grip_id: String, upper_bone_id: String, lower_bone_id: String, hand_bone_id: String, hand_pose_id: String = "", bend_sign: float = 1.0) -> bool:
	if weapon == null or pose_profile == null or weapon.get_grip(grip_id) == null:
		return false
	var accepted: bool = pose_profile.set_hand_binding({
		"grip_id": grip_id,
		"upper_bone_id": upper_bone_id,
		"lower_bone_id": lower_bone_id,
		"hand_bone_id": hand_bone_id,
		"hand_pose_id": hand_pose_id,
		"bend_sign": bend_sign
	})
	if accepted:
		pose_changed.emit()
	return accepted


func get_preview() -> Dictionary:
	var preview := {"compatible": false, "weapon_transform": {}, "grips": []}
	if weapon == null or pose_profile == null:
		return preview
	preview["compatible"] = weapon.is_compatible_with_body_type(body_type_id)
	preview["weapon_transform"] = pose_profile.resolve_transform(body_type_id, direction_id, animation_id)
	for grip_id in weapon.grips:
		var target := WeaponPoseSolver.resolve_grip_target(weapon, pose_profile, grip_id, body_type_id, direction_id, animation_id)
		preview["grips"].append({
			"grip_id": grip_id,
			"position": target.get("position", Vector2.ZERO),
			"rotation": target.get("rotation", 0.0),
			"bound": not pose_profile.get_binding_for_grip(grip_id).is_empty()
		})
	return preview


func set_solver_options(options: Dictionary) -> void:
	solver_options = options.duplicate(true)


func get_solver_overlays() -> Array:
	return (last_solver_result.get("overlays", []) as Array).duplicate(true)


func get_solver_instrumentation() -> Dictionary:
	return (last_solver_result.get("instrumentation", {}) as Dictionary).duplicate(true)


func align_hands(rig: Dictionary, hand_pose_library = null, influence: float = 1.0, options: Dictionary = {}) -> Dictionary:
	if weapon == null or pose_profile == null:
		return {"success": false, "errors": ["Weapon and pose profile are required"]}
	var effective_options := solver_options.duplicate(true)
	effective_options.merge(options, true)
	var result := WeaponPoseSolver.solve_pose(rig, weapon, pose_profile, hand_pose_library, body_type_id, direction_id, animation_id, influence, effective_options)
	last_solver_result = result.duplicate(true)
	if result.get("success", false):
		pose_changed.emit()
	return result
