# WeaponAuthoringWizardModel -- Coverage, workflow, and repair model for weapon authoring.
class_name WeaponAuthoringWizardModel
extends RefCounted

const WORKFLOWS := ["standard", "dual_wield", "shield", "bow", "flexible"]

var weapon = null
var pose_profile = null
var rig: Dictionary = {}
var hand_pose_library = null
var body_type_ids: Array = []
var direction_ids: Array = []
var workflow_id: String = "standard"
var holster_socket_id: String = ""
var draw_sheath_offsets: Dictionary = {}
var _last_coverage: Dictionary = {}


func bind_context(p_weapon, p_profile, p_rig: Dictionary, p_hand_pose_library = null) -> void:
	weapon = p_weapon
	pose_profile = p_profile
	rig = p_rig.duplicate(true)
	hand_pose_library = p_hand_pose_library
	_last_coverage = {}


func set_coverage_dimensions(p_body_type_ids: Array, p_direction_ids: Array) -> void:
	body_type_ids = _unique_strings(p_body_type_ids)
	direction_ids = _unique_strings(p_direction_ids)
	_last_coverage = {}


func set_workflow(p_workflow_id: String) -> bool:
	if p_workflow_id not in WORKFLOWS:
		return false
	workflow_id = p_workflow_id
	return true


func set_holster_socket(socket_id: String, body_bone_id: String, local_position: Vector2 = Vector2.ZERO, local_rotation: float = 0.0) -> bool:
	if weapon == null or socket_id.strip_edges().is_empty() or body_bone_id.strip_edges().is_empty():
		return false
	weapon.sockets[socket_id.strip_edges()] = {"name": socket_id.strip_edges().capitalize(), "body_bone_id": body_bone_id.strip_edges(), "local_position": [local_position.x, local_position.y], "local_rotation": local_rotation}
	holster_socket_id = socket_id.strip_edges()
	return true


func set_draw_sheath_offsets(draw_offset: Dictionary, sheath_offset: Dictionary) -> bool:
	if pose_profile == null:
		return false
	pose_profile.animation_offsets["draw"] = draw_offset.duplicate(true)
	pose_profile.animation_offsets["sheath"] = sheath_offset.duplicate(true)
	draw_sheath_offsets = {"draw": draw_offset.duplicate(true), "sheath": sheath_offset.duplicate(true)}
	return true


func evaluate_coverage() -> Dictionary:
	if weapon == null or pose_profile == null or rig.is_empty():
		return {"success": false, "errors": ["Weapon, pose profile, and rig are required for coverage."], "cells": []}
	var bodies := body_type_ids if not body_type_ids.is_empty() else _default_body_types()
	var directions := direction_ids if not direction_ids.is_empty() else [""]
	var cells: Array = []
	for body_type_id in bodies:
		for direction_id in directions:
			var solve := WeaponPoseSolver.solve_pose(rig.duplicate(true), weapon, pose_profile, hand_pose_library, body_type_id, direction_id)
			var repairs := _repair_actions(solve, body_type_id, direction_id)
			cells.append({"body_type_id": body_type_id, "direction_id": direction_id, "success": bool(solve.get("success", false)), "solve": solve, "repair_actions": repairs})
	var covered := 0
	for cell in cells:
		if bool(cell["success"]):
			covered += 1
	_last_coverage = {"success": covered == cells.size(), "cells": cells, "covered_count": covered, "total_count": cells.size(), "body_report": _group_coverage(cells, "body_type_id"), "direction_report": _group_coverage(cells, "direction_id")}
	return _last_coverage.duplicate(true)


func get_last_coverage() -> Dictionary:
	return _last_coverage.duplicate(true)


func get_reachability_report() -> Array:
	if _last_coverage.is_empty():
		evaluate_coverage()
	var report: Array = []
	for cell in _last_coverage.get("cells", []):
		for arm in cell.get("solve", {}).get("arms", []):
			report.append({"body_type_id": cell.get("body_type_id", ""), "direction_id": cell.get("direction_id", ""), "reachable": bool(arm.get("reachable", false)), "grip_gap": float(arm.get("grip_gap", 0.0)), "diagnostics": (arm.get("diagnostics", []) as Array).duplicate(true)})
	return report


func validate_workflow() -> Dictionary:
	var errors: Array = []
	if weapon == null or pose_profile == null:
		errors.append("Bind a weapon and pose profile before validating the workflow.")
	else:
		errors.append_array(weapon.validate())
		errors.append_array(pose_profile.validate())
	match workflow_id:
		"dual_wield":
			if weapon == null or weapon.grips.size() < 2:
				errors.append("Dual-wield workflow requires at least two weapon grips.")
		"shield":
			if weapon == null or not weapon.sockets.has("shield"):
				errors.append("Shield workflow requires a named 'shield' socket.")
		"bow":
			if not draw_sheath_offsets.has("draw"):
				errors.append("Bow workflow requires a draw offset.")
		"flexible":
			if pose_profile == null or int(pose_profile.drive_mode) != pose_profile.DriveMode.PATH:
				errors.append("Flexible workflow requires PATH drive mode.")
	return {"success": errors.is_empty(), "errors": errors, "repair_actions": _validation_repairs(errors)}


func to_dict() -> Dictionary:
	return {"schema_version": "1.0.0", "weapon_id": weapon.weapon_id if weapon != null else "", "profile_id": pose_profile.profile_id if pose_profile != null else "", "body_type_ids": body_type_ids.duplicate(), "direction_ids": direction_ids.duplicate(), "workflow_id": workflow_id, "holster_socket_id": holster_socket_id, "draw_sheath_offsets": draw_sheath_offsets.duplicate(true)}


func from_dict(data: Dictionary) -> bool:
	var saved_weapon_id := str(data.get("weapon_id", ""))
	var saved_profile_id := str(data.get("profile_id", ""))
	if weapon == null or pose_profile == null or saved_weapon_id != weapon.weapon_id or saved_profile_id != pose_profile.profile_id:
		return false
	body_type_ids = _unique_strings(data.get("body_type_ids", []))
	direction_ids = _unique_strings(data.get("direction_ids", []))
	if not set_workflow(str(data.get("workflow_id", "standard"))):
		return false
	holster_socket_id = str(data.get("holster_socket_id", ""))
	draw_sheath_offsets = (data.get("draw_sheath_offsets", {}) as Dictionary).duplicate(true)
	return true


func _default_body_types() -> Array:
	if weapon != null and not weapon.supported_body_types.is_empty():
		return Array(weapon.supported_body_types)
	return [""]


func _group_coverage(cells: Array, key: String) -> Dictionary:
	var report: Dictionary = {}
	for cell in cells:
		var value := str(cell.get(key, ""))
		if not report.has(value):
			report[value] = {"covered": 0, "total": 0}
		report[value]["total"] += 1
		if bool(cell.get("success", false)):
			report[value]["covered"] += 1
	return report


func _repair_actions(solve: Dictionary, body_type_id: String, direction_id: String) -> Array:
	var actions: Array = []
	for diagnostic in solve.get("diagnostics", []):
		var code := str(diagnostic.get("code", ""))
		if code == "UNREACHABLE_GRIP":
			actions.append({"action": "adjust_reach", "body_type_id": body_type_id, "direction_id": direction_id, "message": "Move the grip or increase authored shoulder allowance."})
		elif code == "GRIP_GAP" or code == "JOINT_LIMIT":
			actions.append({"action": "adjust_joint_limits", "body_type_id": body_type_id, "direction_id": direction_id, "message": "Adjust the grip target, pole, or joint limits."})
	if actions.is_empty() and not bool(solve.get("success", false)):
		actions.append({"action": "inspect_binding", "body_type_id": body_type_id, "direction_id": direction_id, "message": "Inspect the arm binding and required grip."})
	return actions


func _validation_repairs(errors: Array) -> Array:
	var actions: Array = []
	for message in errors:
		actions.append({"action": "repair_validation", "message": str(message)})
	return actions


func _unique_strings(values: Array) -> Array:
	var result: Array = []
	for value in values:
		var normalized := str(value).strip_edges()
		if not normalized.is_empty() and normalized not in result:
			result.append(normalized)
	return result
