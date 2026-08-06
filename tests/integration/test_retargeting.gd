# Covers the skeleton-profile contract introduced by RET-001.
extends Node

const SkeletonProfileScript = preload("res://rigging/retargeting/skeleton_profile.gd")
const RetargetBoneMapScript = preload("res://rigging/retargeting/retarget_bone_map.gd")
const ProportionCompensationScript = preload("res://rigging/retargeting/proportion_compensation.gd")
const RetargetPoseTransferScript = preload("res://rigging/retargeting/retarget_pose_transfer.gd")
const RetargetPreviewPanelScene = preload("res://rigging/retargeting/retarget_preview_panel.tscn")
const PoseDefinitionScript = preload("res://rigging/poses/pose_definition.gd")
const RetargetBatchProcessorScript = preload("res://rigging/retargeting/retarget_batch_processor.gd")
const RetargetCorrectionLayerScript = preload("res://rigging/retargeting/retarget_correction_layer.gd")
const PoseLibraryScript = preload("res://rigging/poses/pose_library.gd")


func run_tests() -> Dictionary:
	var profile = SkeletonProfileScript.new("hero_humanoid", "Hero Humanoid")
	profile.rig_id = "hero_rig"
	profile.metadata = {"species": "human"}
	var root_set: bool = profile.set_bone_role("root", "pelvis")
	var hand_set: bool = profile.set_bone_role("hand left", "wrist_l")
	var restored = SkeletonProfileScript.new().from_dict(profile.to_dict())
	var duplicate := SkeletonProfileScript.new("bad", "Bad")
	duplicate.set_bone_role("root", "pelvis")
	duplicate.set_bone_role("hips", "pelvis")
	var target = SkeletonProfileScript.new("small_humanoid", "Small Humanoid")
	target.set_bone_role("root", "target_pelvis")
	target.set_bone_role("hand_left", "target_wrist_l")
	target.set_bone_role("head", "target_head")
	var mapping: Dictionary = RetargetBoneMapScript.build(profile, target)
	var partial_target = SkeletonProfileScript.new("partial", "Partial")
	partial_target.set_bone_role("root", "partial_root")
	var partial_mapping: Dictionary = RetargetBoneMapScript.build(profile, partial_target)
	var invalid_mapping: Array = RetargetBoneMapScript.validate_map({"pelvis": "target_pelvis", "wrist_l": "target_pelvis"}, ["pelvis", "wrist_l"], ["target_pelvis", "target_wrist_l"])
	var source_rig := {"bones": {"pelvis": {"length": 10.0}, "wrist_l": {"length": 20.0}}}
	var target_rig := {"bones": {"target_pelvis": {"length": 15.0}, "target_wrist_l": {"length": 10.0}}}
	var proportions: Dictionary = ProportionCompensationScript.compute(source_rig, target_rig, mapping.get("bone_map", {}))
	var invalid_proportions: Dictionary = ProportionCompensationScript.compute({"bones": {"pelvis": {"length": 0.0}}}, target_rig, {"pelvis": "target_pelvis"})
	var source_pose := PoseDefinitionScript.new("source_reach", "Source Reach")
	source_pose.rig_profile_id = "hero_rig"
	source_pose.set_bone_transform("pelvis", {"position": [4.0, 2.0], "rotation": 0.3, "scale": [1.0, 1.0]})
	source_pose.set_bone_transform("wrist_l", {"position": [6.0, -2.0], "rotation": -0.4, "scale": [1.0, 1.0]})
	target.rig_id = "target_rig"
	var transferred: Dictionary = RetargetPoseTransferScript.preview(source_pose, target, mapping.get("bone_map", {}), proportions.get("factors", {}), "target_reach", "Target Reach")
	var target_pelvis: Dictionary = transferred.get("pose").get_bone_transform("target_pelvis") if transferred.get("success", false) else {}
	var preview_panel := RetargetPreviewPanelScene.instantiate()
	add_child(preview_panel)
	var target_apply_rig := {"id": "target_rig", "bones": {"target_pelvis": {"local_position": Vector2.ZERO, "local_rotation": 0.0, "local_scale": Vector2.ONE}, "target_wrist_l": {"local_position": Vector2.ZERO, "local_rotation": 0.0, "local_scale": Vector2.ONE}}}
	preview_panel.bind_context(source_pose, target, target_apply_rig, mapping.get("bone_map", {}), proportions.get("factors", {}))
	var previewed: Dictionary = preview_panel.preview_retarget()
	var retarget_preview_ok: bool = transferred.get("success", false) and target_pelvis.get("position", []) == [6.0, 3.0] and previewed.get("success", false) and target_apply_rig["bones"]["target_pelvis"]["local_position"] == Vector2(6, 3)
	var second_pose := PoseDefinitionScript.new("source_idle", "Source Idle")
	second_pose.rig_profile_id = "hero_rig"
	second_pose.set_bone_transform("pelvis", {"position": [2.0, 0.0]})
	second_pose.set_bone_transform("wrist_l", {"position": [4.0, 0.0]})
	var target_library = PoseLibraryScript.new()
	var batched: Dictionary = preview_panel.batch_retarget([source_pose, second_pose], target_library, "small")
	var corrections = RetargetCorrectionLayerScript.new("small_reach_fix")
	corrections.target_profile_id = "small_humanoid"
	corrections.set_bone_offset("target_pelvis", {"position": [1.0, -1.0], "rotation": 0.1, "scale": [1.1, 1.0]})
	var corrected: Dictionary = corrections.apply_to_pose(transferred.get("pose"))
	var corrected_pelvis: Dictionary = transferred.get("pose").get_bone_transform("target_pelvis")
	preview_panel.bind_context(source_pose, target, target_apply_rig, mapping.get("bone_map", {}), proportions.get("factors", {}), corrections)
	var corrected_preview: Dictionary = preview_panel.preview_retarget()
	preview_panel.queue_free()
	var checks := {
		"valid_profile": root_set and hand_set and profile.validate(["pelvis", "wrist_l"]).is_empty(),
		"normalisation": profile.get_bone_id("hand_left") == "wrist_l" and not profile.set_bone_role("", "bad"),
		"round_trip": restored.profile_id == "hero_humanoid" and restored.rig_id == "hero_rig" and restored.metadata == profile.metadata and restored.get_bone_id("root") == "pelvis",
		"invalid_profile": not duplicate.validate().is_empty() and not profile.validate(["pelvis"]).is_empty(),
		"semantic_mapping": mapping.get("success", false) and mapping.get("complete", false) and mapping.get("bone_map", {}).get("pelvis", "") == "target_pelvis" and mapping.get("bone_map", {}).get("wrist_l", "") == "target_wrist_l",
		"mapping_diagnostics": partial_mapping.get("success", false) and not partial_mapping.get("complete", true) and partial_mapping.get("missing_target_roles", []) == ["hand_left"] and not invalid_mapping.is_empty(),
		"proportion_compensation": proportions.get("success", false) and is_equal_approx(float(proportions.get("factors", {}).get("target_pelvis", 0.0)), 1.5) and is_equal_approx(float(proportions.get("factors", {}).get("target_wrist_l", 0.0)), 0.5) and ProportionCompensationScript.scale_position(Vector2(4, -2), 1.5) == Vector2(6, -3) and not invalid_proportions.get("success", true),
		"retarget_preview": retarget_preview_ok,
		"batch_retarget": batched.get("success", false) and batched.get("results", []).size() == 2 and target_library.get_pose_ids() == ["small_source_idle", "small_source_reach"],
		"correction_layers": corrected.get("success", false) and corrected_pelvis.get("position", []) == [7.0, 2.0] and is_equal_approx(float(corrected_pelvis.get("rotation", 0.0)), 0.4) and corrected_preview.get("success", false) and target_apply_rig["bones"]["target_pelvis"]["local_position"] == Vector2(7, 2),
	}
	if _all_true(checks):
		print("  PASS: Retarget profiles, maps, compensation, preview, batch, and correction layers work")
		return {"passed": 1, "failed": 0, "errors": []}
	return {"passed": 0, "failed": 1, "errors": ["Skeleton profile acceptance failed: %s" % checks]}


func _all_true(checks: Dictionary) -> bool:
	for value in checks.values():
		if not bool(value):
			return false
	return true
