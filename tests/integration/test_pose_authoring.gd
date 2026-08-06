# Covers the serializable pose schema introduced by POS-001.
extends Node

const PoseDefinitionScript = preload("res://rigging/poses/pose_definition.gd")
const PoseLibraryScript = preload("res://rigging/poses/pose_library.gd")
const PoseApplierScript = preload("res://rigging/poses/pose_applier.gd")
const PoseLibraryPanelScene = preload("res://rigging/poses/pose_library_panel.tscn")
const PoseMirrorModelScript = preload("res://rigging/poses/pose_mirror_model.gd")
const PoseBlendModelScript = preload("res://rigging/poses/pose_blend_model.gd")
const PoseThumbnailModelScript = preload("res://rigging/poses/pose_thumbnail_model.gd")
const PoseSketchAssistModelScript = preload("res://rigging/poses/pose_sketch_assist_model.gd")


func run_tests() -> Dictionary:
	var pose = PoseDefinitionScript.new("hero_idle", "Hero Idle")
	pose.rig_profile_id = "hero_rig"
	pose.tags = ["idle", "default", "idle"]
	pose.metadata = {"author": "test", "frame": 0}
	var root_set: bool = pose.set_bone_transform("root", {"position": Vector2(4.0, -2.0), "rotation": 0.25, "scale": Vector2(1.0, 1.1)})
	var hand_set: bool = pose.set_bone_transform("hand_left", {"local_position": [8.0, 3.0], "local_rotation": -0.5})
	var empty_bone_rejected: bool = not pose.set_bone_transform("", {})
	var restored = PoseDefinitionScript.new().from_dict(pose.to_dict())
	var root: Dictionary = restored.get_bone_transform("root")
	var hand: Dictionary = restored.get_bone_transform("hand_left")
	var invalid := PoseDefinitionScript.new()
	var rig := {"id": "hero_rig", "bones": {
		"root": {"local_position": Vector2(3, 4), "local_rotation": 0.2, "local_scale": Vector2(1, 1)},
		"hand_left": {"local_position": Vector2(9, -2), "local_rotation": -0.4, "local_scale": Vector2(1.2, 0.8)},
	}}
	var saved_pose := PoseDefinitionScript.new("ready", "Ready")
	var captured: Dictionary = PoseApplierScript.capture_from_rig(saved_pose, rig)
	var library = PoseLibraryScript.new()
	var saved: Dictionary = library.save_pose(saved_pose)
	rig["bones"]["root"]["local_position"] = Vector2.ZERO
	rig["bones"]["hand_left"]["local_rotation"] = 0.0
	var applied: Dictionary = PoseApplierScript.apply_to_rig(library.get_pose("ready"), rig)
	var capture_and_apply_ok: bool = captured.get("success", false) and saved.get("success", false) and applied.get("success", false) and rig["bones"]["root"]["local_position"] == Vector2(3, 4) and is_equal_approx(rig["bones"]["hand_left"]["local_rotation"], -0.4)
	var library_round_trip := PoseLibraryScript.new()
	var loaded: Dictionary = library_round_trip.from_dict(library.to_dict())
	var wrong_rig: Dictionary = PoseApplierScript.apply_to_rig(library.get_pose("ready"), {"id": "other_rig", "bones": {}})
	var additive := PoseDefinitionScript.new("lean_delta", "Lean Delta")
	additive.rig_profile_id = "hero_rig"
	additive.mode = 1
	additive.set_bone_transform("root", {"position": [2.0, -1.0], "rotation": 0.2, "scale": [1.5, 0.5]})
	var additive_rig := {"id": "hero_rig", "bones": {"root": {"local_position": Vector2(4, 3), "local_rotation": 0.1, "local_scale": Vector2(2, 2)}}}
	var additive_applied: Dictionary = PoseApplierScript.apply_to_rig(additive, additive_rig)
	var panel := PoseLibraryPanelScene.instantiate()
	add_child(panel)
	panel.bind_rig(rig)
	(panel.get_node("Form/PoseIdInput") as LineEdit).text = "panel_capture"
	(panel.get_node("Form/DisplayNameInput") as LineEdit).text = "Panel Capture"
	var panel_saved: Dictionary = panel.capture_current_pose()
	(panel.get_node("Form/PoseMode") as OptionButton).select(1)
	(panel.get_node("Form/PoseIdInput") as LineEdit).text = "panel_additive"
	var panel_additive: Dictionary = panel.capture_current_pose()
	rig["bones"]["root"]["local_position"] = Vector2(-8, 7)
	var panel_applied: Dictionary = panel.apply_pose("panel_capture")
	var user_panel_ok: bool = panel_saved.get("success", false) and panel_applied.get("success", false) and rig["bones"]["root"]["local_position"] == Vector2(3, 4)
	var asymmetric := PoseDefinitionScript.new("left_reach", "Left Reach")
	asymmetric.set_bone_transform("hand_left", {"position": [5.0, 3.0], "rotation": 0.4, "scale": [1.2, 0.9]})
	asymmetric.set_bone_transform("root", {"position": [0.0, 1.0], "rotation": 0.1})
	var mirrored: Dictionary = PoseMirrorModelScript.mirror_pose(asymmetric, "right_reach", "Right Reach", {"hand_left": "hand_right", "hand_right": "hand_left"})
	var mirrored_hand: Dictionary = mirrored.get("pose").get_bone_transform("hand_right") if mirrored.get("success", false) else {}
	var invalid_mirror: Dictionary = PoseMirrorModelScript.mirror_pose(asymmetric, "bad", "Bad", {"hand_left": "hand_right"})
	var panel_source := PoseDefinitionScript.new("panel_left", "Panel Left")
	panel_source.set_bone_transform("hand_left", {"position": [2.0, 0.0], "rotation": 0.3})
	panel.save_pose(panel_source)
	var panel_mirrored: Dictionary = panel.mirror_pose("panel_left", "panel_right", "Panel Right", "hand_left:hand_right")
	var blend_a := PoseDefinitionScript.new("blend_a", "Blend A")
	blend_a.rig_profile_id = "hero_rig"
	blend_a.set_bone_transform("root", {"position": [0.0, 2.0], "rotation": 0.0, "scale": [1.0, 1.0]})
	var blend_b := PoseDefinitionScript.new("blend_b", "Blend B")
	blend_b.rig_profile_id = "hero_rig"
	blend_b.set_bone_transform("root", {"position": [10.0, -2.0], "rotation": 0.6, "scale": [1.4, 0.8]})
	var blended: Dictionary = PoseBlendModelScript.blend_poses(blend_a, blend_b, "blend_mid", "Blend Mid", 0.25)
	var blended_root: Dictionary = blended.get("pose").get_bone_transform("root") if blended.get("success", false) else {}
	var blended_position: Array = blended_root.get("position", []) as Array
	var blended_scale: Array = blended_root.get("scale", []) as Array
	var blend_model_ok: bool = blended.get("success", false) and blended_position.size() == 2 and blended_scale.size() == 2 and is_equal_approx(float(blended_position[0]), 2.5) and is_equal_approx(float(blended_position[1]), 1.0) and is_equal_approx(float(blended_root.get("rotation", 0.0)), 0.15) and is_equal_approx(float(blended_scale[0]), 1.1) and is_equal_approx(float(blended_scale[1]), 0.95)
	var incompatible: Dictionary = PoseBlendModelScript.blend_poses(blend_a, asymmetric, "bad_blend", "Bad", 0.5)
	panel.save_pose(blend_a)
	panel.save_pose(blend_b)
	var panel_blended: Dictionary = panel.blend_poses("blend_a", "blend_b", "panel_blend", "Panel Blend", 0.5)
	var source_option := panel.get_node("Form/PoseList") as OptionButton
	var target_option := panel.get_node("BlendTargetList") as OptionButton
	source_option.select(_option_index(source_option, "blend_a"))
	target_option.select(_option_index(target_option, "blend_b"))
	(panel.get_node("BlendWeight") as HSlider).value = 0.5
	var preview_blended: Dictionary = panel.preview_selected_blend()
	var blend_panel_ok: bool = panel_blended.get("success", false) and preview_blended.get("success", false) and panel.get_pose_library().get_pose("panel_blend") != null and rig["bones"]["root"]["local_position"] == Vector2(5, 0)
	var thumbnail: Dictionary = PoseThumbnailModelScript.render_pose(asymmetric)
	var panel_thumbnail: Dictionary = panel.get_pose_thumbnail("blend_a")
	var suggested: Dictionary = PoseSketchAssistModelScript.suggest_pose("sketch_reach", "Sketch Reach", rig, [Vector2(10, 30), Vector2(100, 60), Vector2(160, 20)])
	var rejected_sketch: Dictionary = PoseSketchAssistModelScript.suggest_pose("bad_sketch", "Bad", rig, [])
	(panel.get_node("Form/PoseIdInput") as LineEdit).text = "panel_sketch"
	(panel.get_node("Form/DisplayNameInput") as LineEdit).text = "Panel Sketch"
	panel.get_node("SketchCanvas").call("set_points", [Vector2(10, 30), Vector2(110, 70), Vector2(180, 20)])
	var panel_suggested: Dictionary = panel.suggest_from_sketch()
	panel.queue_free()
	var checks := {
		"valid_schema": pose.validate().is_empty() and root_set and hand_set and empty_bone_rejected,
		"normalisation": root.get("position", []) == [4.0, -2.0] and is_equal_approx(float(root.get("rotation", 0.0)), 0.25) and hand.get("position", []) == [8.0, 3.0],
		"round_trip": restored.pose_id == "hero_idle" and restored.rig_profile_id == "hero_rig" and restored.tags == ["idle", "default"] and restored.metadata == pose.metadata,
		"invalid_state": not invalid.validate().is_empty(),
		"capture_and_apply": capture_and_apply_ok,
		"library_round_trip": loaded.get("success", false) and library_round_trip.get_pose_ids() == ["ready"],
		"rig_mismatch_rejected": not wrong_rig.get("success", true),
		"additive_apply": additive_applied.get("success", false) and additive_rig["bones"]["root"]["local_position"] == Vector2(6, 2) and is_equal_approx(additive_rig["bones"]["root"]["local_rotation"], 0.3) and additive_rig["bones"]["root"]["local_scale"] == Vector2(3, 1),
		"user_panel": user_panel_ok,
		"additive_panel": panel_additive.get("success", false) and int(panel.get_pose_library().get_pose("panel_additive").mode) == 1,
		"mirror_model": mirrored.get("success", false) and mirrored_hand.get("position", []) == [-5.0, 3.0] and is_equal_approx(float(mirrored_hand.get("rotation", 0.0)), -0.4) and not invalid_mirror.get("success", true),
		"mirror_panel": panel_mirrored.get("success", false) and panel.get_pose_library().get_pose("panel_right") != null,
		"blend_model": blend_model_ok and not incompatible.get("success", true),
		"blend_panel": blend_panel_ok,
		"thumbnails": thumbnail.get("success", false) and (thumbnail.get("image") as Image).get_size() == Vector2i(128, 96) and int(thumbnail.get("bone_count", 0)) == 2 and panel_thumbnail.get("success", false) and panel_thumbnail.get("texture") != null,
		"sketch_assistance": suggested.get("success", false) and (suggested.get("pose").bone_transforms as Dictionary).size() == 2 and not rejected_sketch.get("success", true) and panel_suggested.get("success", false) and panel.get_pose_library().get_pose("panel_sketch") != null,
	}
	if _all_true(checks):
		print("  PASS: Pose schema/library capture, apply, mirror, blend, additive, thumbnail, and sketch workflows")
		return {"passed": 1, "failed": 0, "errors": []}
	return {"passed": 0, "failed": 1, "errors": ["Pose schema acceptance failed: %s" % checks]}


func _all_true(checks: Dictionary) -> bool:
	for value in checks.values():
		if not bool(value):
			return false
	return true


func _option_index(option: OptionButton, item_text: String) -> int:
	for index in range(option.item_count):
		if option.get_item_text(index) == item_text:
			return index
	return -1
