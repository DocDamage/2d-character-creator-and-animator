# HandPoseLibrary -- Reusable hand attachment pose collection.
class_name HandPoseLibrary
extends RefCounted

var _poses: Dictionary = {}


func add_pose(hand_pose) -> bool:
	if hand_pose == null or hand_pose.hand_pose_id.is_empty() or _poses.has(hand_pose.hand_pose_id):
		return false
	_poses[hand_pose.hand_pose_id] = hand_pose.to_dict()
	return true


func get_pose(hand_pose_id: String):
	if not _poses.has(hand_pose_id):
		return null
	var hand_pose := HandPoseDefinition.new()
	hand_pose.from_dict(_poses[hand_pose_id])
	return hand_pose


func find_for_side(hand_side: String) -> Array:
	var result: Array = []
	for pose_data in _poses.values():
		var hand_pose := HandPoseDefinition.new()
		hand_pose.from_dict(pose_data)
		if hand_pose.hand_side == hand_side or hand_pose.hand_side == "either":
			result.append(hand_pose)
	return result


func to_dict() -> Dictionary:
	return {"hand_poses": _poses.duplicate(true)}


func from_dict(data: Dictionary) -> void:
	_poses = (data.get("hand_poses", {}) as Dictionary).duplicate(true)
