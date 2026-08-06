# Unit Tests for master-plan weapon authoring wizard workflows.
extends Node

const WizardModelScript = preload("res://weapons/authoring/weapon_authoring_wizard_model.gd")
const WizardScene = preload("res://weapons/authoring/weapon_authoring_wizard.tscn")
const WeaponDefinitionScript = preload("res://weapons/definitions/weapon_definition.gd")
const GripDefinitionScript = preload("res://weapons/grips/grip_definition.gd")
const WeaponPoseProfileScript = preload("res://weapons/poses/weapon_pose_profile.gd")
const RigSchemaScript = preload("res://rigging/bones/rig_schema.gd")
const BoneSchemaScript = preload("res://rigging/bones/bone_schema.gd")


func run_tests() -> int:
	var passes := 0
	passes += test_coverage_reports_and_repairs()
	passes += test_special_workflows_and_session_persistence()
	passes += test_user_reachable_wizard_controls()
	return passes


func test_coverage_reports_and_repairs() -> int:
	var model = _model()
	model.set_coverage_dimensions(["tall", "medium"], ["north", "east"])
	var coverage: Dictionary = model.evaluate_coverage()
	var reachability: Array = model.get_reachability_report()
	model.pose_profile.base_position = Vector2(140.0, 0.0)
	var failed: Dictionary = model.evaluate_coverage()
	var repairs: Array = failed.get("cells", [])[0].get("repair_actions", [])
	if coverage.get("success", false) and coverage.get("cells", []).size() == 4 and int(coverage.get("body_report", {}).get("tall", {}).get("covered", 0)) == 2 and int(coverage.get("direction_report", {}).get("east", {}).get("covered", 0)) == 2 and reachability.size() == 8 and not failed.get("success", true) and not repairs.is_empty() and repairs[0].get("action", "") == "adjust_reach":
		print("  PASS: WPA-001/WPA-002/WPA-003/WPA-004/WPA-011/WPA-012/WPA-013 coverage reports expose repairs")
		return 1
	printerr("  FAIL: WPA coverage or repair report failed: %s" % str(failed))
	return 0


func test_special_workflows_and_session_persistence() -> int:
	var model = _model()
	var dual: bool = model.set_workflow("dual_wield") and model.validate_workflow().get("success", false)
	var holster: bool = model.set_holster_socket("shield", "root", Vector2(2.0, 3.0), 0.1)
	var shield: bool = model.set_workflow("shield") and model.validate_workflow().get("success", false)
	var transitions: bool = model.set_draw_sheath_offsets({"position": Vector2(2.0, 0.0)}, {"position": Vector2(-2.0, 0.0)})
	var bow: bool = model.set_workflow("bow") and model.validate_workflow().get("success", false)
	model.pose_profile.drive_mode = model.pose_profile.DriveMode.PATH
	model.pose_profile.drive_settings = {"path_id": "whip"}
	var flexible: bool = model.set_workflow("flexible") and model.validate_workflow().get("success", false)
	model.set_coverage_dimensions(["tall"], ["north"])
	var session: Dictionary = model.to_dict()
	var restored = _model()
	restored.pose_profile.drive_mode = restored.pose_profile.DriveMode.PATH
	restored.pose_profile.drive_settings = {"path_id": "whip"}
	var restored_ok: bool = restored.from_dict(session)
	if dual and holster and shield and transitions and bow and flexible and restored_ok and restored.workflow_id == "flexible" and restored.body_type_ids == ["tall"] and restored.draw_sheath_offsets.has("draw"):
		print("  PASS: WPA-005/WPA-006/WPA-007/WPA-008/WPA-009/WPA-010/WPA-014 special workflows persist")
		return 1
	printerr("  FAIL: WPA special workflow or persistence failed: %s" % str(session))
	return 0


func test_user_reachable_wizard_controls() -> int:
	var wizard: Control = WizardScene.instantiate() as Control
	var fixture = _model()
	wizard.call("bind_context", fixture.weapon, fixture.pose_profile, fixture.rig)
	wizard.call("set_coverage_dimensions", ["tall"], ["north"])
	var coverage: Dictionary = wizard.call("run_coverage")
	var saved: Dictionary = wizard.call("save_session")
	var coverage_button := wizard.get_node("Margin/RootVBox/ActionsRow/CoverageButton") as Button
	var reachable: bool = coverage_button.focus_mode == Control.FOCUS_ALL and wizard.call("restore_session", saved)
	var reachability: Array = wizard.call("get_reachability_report")
	wizard.free()
	if coverage.get("success", false) and reachable and reachability.size() == 2:
		print("  PASS: WPA-015 wizard controls are focusable and expose coverage interaction")
		return 1
	printerr("  FAIL: WPA user-reachable wizard controls failed")
	return 0


func _model():
	var model := WizardModelScript.new()
	var weapon := WeaponDefinitionScript.new("rifle", "Wizard Rifle")
	weapon.asset_id = "asset_rifle"
	weapon.interaction_family_id = "rifle"
	weapon.supported_body_types = ["tall", "medium"]
	weapon.add_grip(GripDefinitionScript.new("primary", "Primary", GripDefinitionScript.Role.PRIMARY))
	var secondary := GripDefinitionScript.new("secondary", "Secondary", GripDefinitionScript.Role.SECONDARY)
	secondary.local_position = Vector2(15.0, 0.0)
	weapon.add_grip(secondary)
	var profile := WeaponPoseProfileScript.new("wizard_pose", "Wizard Pose")
	profile.weapon_id = weapon.weapon_id
	profile.base_position = Vector2(25.0, 0.0)
	profile.set_hand_binding(_binding("primary", "upper_r", "lower_r", "hand_r"))
	profile.set_hand_binding(_binding("secondary", "upper_l", "lower_l", "hand_l"))
	model.bind_context(weapon, profile, _rig())
	return model


func _binding(grip_id: String, upper: String, lower: String, hand: String) -> Dictionary:
	return {"grip_id": grip_id, "upper_bone_id": upper, "lower_bone_id": lower, "hand_bone_id": hand, "bend_sign": 1.0}


func _rig() -> Dictionary:
	var rig := RigSchemaScript.create_empty_rig("wizard", "Wizard Rig")
	var root := BoneSchemaScript.create_default_bone("root", "Root")
	rig["bones"] = {"root": root}
	for side in ["r", "l"]:
		var upper := BoneSchemaScript.create_default_bone("upper_" + side, "Upper", "root")
		upper["length"] = 40.0
		var lower := BoneSchemaScript.create_default_bone("lower_" + side, "Lower", "upper_" + side)
		lower["length"] = 30.0
		lower["local_position"] = Vector2(40.0, 0.0)
		var hand := BoneSchemaScript.create_default_bone("hand_" + side, "Hand", "lower_" + side)
		hand["local_position"] = Vector2(30.0, 0.0)
		rig["bones"].merge({"upper_" + side: upper, "lower_" + side: lower, "hand_" + side: hand})
	rig["root_bone_id"] = "root"
	return rig
