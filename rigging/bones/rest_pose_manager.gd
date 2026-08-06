# RestPoseManager — Manages bind pose / rest pose capturing, storing, and restoration
class_name RestPoseManager
extends RefCounted


static func capture_rest_pose(p_rig: Dictionary) -> Dictionary:
	var rest_pose := {}
	var bones: Dictionary = p_rig.get("bones", {})
	for b_id in bones:
		var bone: Dictionary = bones[b_id]
		rest_pose[b_id] = {
			"rest_position": bone.get("local_position", Vector2.ZERO),
			"rest_rotation": bone.get("local_rotation", 0.0),
			"rest_scale": bone.get("local_scale", Vector2.ONE),
			"rest_angle": bone.get("rest_angle", 0.0),
			"length": bone.get("length", 50.0)
		}
	return rest_pose


static func apply_rest_pose(p_rig: Dictionary, p_rest_pose: Dictionary) -> void:
	var bones: Dictionary = p_rig.get("bones", {})
	for b_id in p_rest_pose:
		if bones.has(b_id):
			var bone: Dictionary = bones[b_id]
			var entry: Dictionary = p_rest_pose[b_id]
			bone["rest_position"] = entry.get("rest_position", Vector2.ZERO)
			bone["rest_rotation"] = entry.get("rest_rotation", 0.0)
			bone["rest_scale"] = entry.get("rest_scale", Vector2.ONE)
			bone["rest_angle"] = entry.get("rest_angle", 0.0)
			bone["length"] = entry.get("length", 50.0)


static func restore_rig_to_rest_pose(p_rig: Dictionary) -> void:
	var bones: Dictionary = p_rig.get("bones", {})
	for b_id in bones:
		var bone: Dictionary = bones[b_id]
		bone["local_position"] = bone.get("rest_position", Vector2.ZERO)
		bone["local_rotation"] = bone.get("rest_rotation", 0.0)
		bone["local_scale"] = bone.get("rest_scale", Vector2.ONE)
