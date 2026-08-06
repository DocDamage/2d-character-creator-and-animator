# RetargetBatchProcessor -- Retargets a collection of source poses with per-pose diagnostics.
class_name RetargetBatchProcessor
extends RefCounted

const RetargetPoseTransferScript = preload("res://rigging/retargeting/retarget_pose_transfer.gd")


static func retarget_to_library(source_poses: Array, target_profile: Variant, bone_map: Dictionary, factors: Dictionary, target_library: Variant, id_prefix: String = "retargeted") -> Dictionary:
	if target_library == null:
		return {"success": false, "results": [], "errors": ["A target pose library is required."]}
	var results: Array = []
	var errors: Array[String] = []
	for source_pose in source_poses:
		if source_pose == null:
			errors.append("A batch entry has no source pose.")
			continue
		var target_id := "%s_%s" % [id_prefix.strip_edges() if not id_prefix.strip_edges().is_empty() else "retargeted", str(source_pose.pose_id)]
		var transferred: Dictionary = RetargetPoseTransferScript.preview(source_pose, target_profile, bone_map, factors, target_id, str(source_pose.display_name) + " Retargeted")
		if not transferred.get("success", false):
			errors.append("%s: %s" % [str(source_pose.pose_id), str(transferred.get("message", "transfer failed"))])
			continue
		var saved: Dictionary = target_library.save_pose(transferred.get("pose"))
		if not saved.get("success", false):
			errors.append("%s: pose library rejected target" % str(source_pose.pose_id))
			continue
		results.append({"source_pose_id": str(source_pose.pose_id), "target_pose_id": target_id, "unmapped_source_bones": transferred.get("unmapped_source_bones", [])})
	return {"success": errors.is_empty(), "results": results, "errors": errors, "message": "Retargeted %d of %d poses." % [results.size(), source_poses.size()]}
