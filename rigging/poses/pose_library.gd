# PoseLibrary -- In-memory, serializable collection of saved named poses.
class_name PoseLibrary
extends RefCounted

const PoseDefinitionScript = preload("res://rigging/poses/pose_definition.gd")

var _poses: Dictionary = {}


func save_pose(pose: Variant) -> Dictionary:
	if pose == null:
		return {"success": false, "errors": ["A pose is required."]}
	var errors: Array = pose.validate()
	if not errors.is_empty():
		return {"success": false, "errors": errors.duplicate()}
	var pose_id := str(pose.pose_id)
	var replaced := _poses.has(pose_id)
	_poses[pose_id] = pose.to_dict()
	return {"success": true, "pose_id": pose_id, "replaced": replaced, "errors": []}


func get_pose(pose_id: String) -> Variant:
	var data: Dictionary = _poses.get(pose_id, {})
	return PoseDefinitionScript.new().from_dict(data) if not data.is_empty() else null


func remove_pose(pose_id: String) -> bool:
	if not _poses.has(pose_id):
		return false
	_poses.erase(pose_id)
	return true


func get_pose_ids() -> Array[String]:
	var ids: Array[String] = []
	for pose_id in _poses:
		ids.append(str(pose_id))
	ids.sort()
	return ids


func is_empty() -> bool:
	return _poses.is_empty()


func to_dict() -> Dictionary:
	var poses: Array = []
	for pose_id in get_pose_ids():
		poses.append((_poses[pose_id] as Dictionary).duplicate(true))
	return {"schema_version": "1.0.0", "poses": poses}


func from_dict(data: Dictionary) -> Dictionary:
	_poses.clear()
	var rejected: Array[String] = []
	for raw_pose in data.get("poses", []) as Array:
		if not raw_pose is Dictionary:
			rejected.append("A pose entry is not an object.")
			continue
		var pose := PoseDefinitionScript.new().from_dict(raw_pose)
		var saved := save_pose(pose)
		if not bool(saved.get("success", false)):
			rejected.append_array(saved.get("errors", []) as Array)
	return {"success": rejected.is_empty(), "rejected": rejected, "pose_ids": get_pose_ids()}
