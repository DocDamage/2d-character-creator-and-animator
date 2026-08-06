# Unit Tests for Weapon Posing Studio and Gameplay Metadata systems.
extends Node

const WeaponDefinitionScript = preload("res://weapons/definitions/weapon_definition.gd")
const GripDefinitionScript = preload("res://weapons/grips/grip_definition.gd")
const WeaponPoseProfileScript = preload("res://weapons/poses/weapon_pose_profile.gd")
const HandPoseDefinitionScript = preload("res://weapons/poses/hand_pose_definition.gd")
const HandPoseLibraryScript = preload("res://weapons/poses/hand_pose_library.gd")
const InteractionFamilyRegistryScript = preload("res://weapons/definitions/interaction_family_registry.gd")
const WeaponRegistryScript = preload("res://weapons/definitions/weapon_registry.gd")
const GripEditorModelScript = preload("res://weapons/grips/grip_editor_model.gd")
const WeaponPosingEditorScript = preload("res://weapons/authoring/weapon_posing_editor.gd")
const WeaponPoseSolverScript = preload("res://weapons/solver/weapon_pose_solver.gd")
const WeaponDriveModesTestsScript = preload("res://tests/unit/test_weapon_drive_modes.gd")
const WeaponSolverTestsScript = preload("res://tests/unit/test_weapon_solver.gd")
const WeaponAuthoringWizardTestsScript = preload("res://tests/unit/test_weapon_authoring_wizard.gd")
const WeaponPhase2MatrixScript = preload("res://tests/integration/test_weapon_phase2_acceptance.gd")
const CharacterAssemblyTestsScript = preload("res://tests/unit/test_character_assembly.gd")
const CharacterCreatorTestsScript = preload("res://tests/integration/test_character_creator.gd")
const MediaAuthoringTestsScript = preload("res://tests/integration/test_media_authoring.gd")
const AnimationBlendingTestsScript = preload("res://tests/unit/test_animation_blending.gd")
const StateMachineAuthoringTestsScript = preload("res://tests/unit/test_state_machine_authoring.gd")
const RuleGraphAuthoringTestsScript = preload("res://tests/unit/test_rule_graph_authoring.gd")
const LinkedProjectTestsScript = preload("res://tests/integration/test_linked_projects.gd")
const RigSchemaScript = preload("res://rigging/bones/rig_schema.gd")
const BoneSchemaScript = preload("res://rigging/bones/bone_schema.gd")
const BoneManagerScript = preload("res://rigging/bones/bone_manager.gd")
const ActionPointDefinitionScript = preload("res://gameplay_metadata/action_points/action_point_definition.gd")
const ActionPointTrackScript = preload("res://gameplay_metadata/action_points/action_point_track.gd")
const CollisionShapeDefinitionScript = preload("res://gameplay_metadata/hitboxes/collision_shape_definition.gd")
const CollisionShapeTrackScript = preload("res://gameplay_metadata/hitboxes/collision_shape_track.gd")
const EventTrackScript = preload("res://gameplay_metadata/events/animation_event_track.gd")
const AudioCueTrackScript = preload("res://gameplay_metadata/events/audio_cue_track.gd")
const VisemeTrackScript = preload("res://gameplay_metadata/events/viseme_track.gd")
const ScriptParameterTrackScript = preload("res://gameplay_metadata/events/script_parameter_track.gd")
const MetadataRegistryScript = preload("res://gameplay_metadata/gameplay_metadata_registry.gd")
const TrackRegistryScript = preload("res://animation/tracks/track_registry.gd")


func run_tests() -> int:
	print("--- Running Weapon Posing & Gameplay Metadata Tests ---")
	var passes := 0
	passes += test_weapon_schemas_and_registries()
	passes += test_dual_grip_editor_preview_and_alignment()
	var drive_mode_tests := WeaponDriveModesTestsScript.new()
	passes += drive_mode_tests.run_tests()
	drive_mode_tests.free()
	var solver_tests := WeaponSolverTestsScript.new()
	passes += solver_tests.run_tests()
	solver_tests.free()
	var wizard_tests := WeaponAuthoringWizardTestsScript.new()
	passes += wizard_tests.run_tests()
	wizard_tests.free()
	var phase2_matrix := WeaponPhase2MatrixScript.new()
	passes += phase2_matrix.run_tests()
	phase2_matrix.free()
	var character_assembly_tests := CharacterAssemblyTestsScript.new()
	passes += character_assembly_tests.run_tests()
	character_assembly_tests.free()
	var character_creator_tests := CharacterCreatorTestsScript.new()
	passes += character_creator_tests.run_tests()
	character_creator_tests.free()
	var media_authoring_tests := MediaAuthoringTestsScript.new()
	passes += media_authoring_tests.run_tests()
	media_authoring_tests.free()
	var animation_blending_tests := AnimationBlendingTestsScript.new()
	passes += animation_blending_tests.run_tests()
	animation_blending_tests.free()
	var state_machine_authoring_tests := StateMachineAuthoringTestsScript.new()
	passes += state_machine_authoring_tests.run_tests()
	state_machine_authoring_tests.free()
	var rule_graph_authoring_tests := RuleGraphAuthoringTestsScript.new()
	passes += rule_graph_authoring_tests.run_tests()
	rule_graph_authoring_tests.free()
	var linked_project_tests := LinkedProjectTestsScript.new()
	passes += linked_project_tests.run_tests()
	linked_project_tests.free()
	passes += test_action_point_and_collision_tracks()
	passes += test_events_audio_visemes_and_parameters()
	passes += test_specialized_track_round_trip()
	print("--- Weapon Posing & Gameplay Metadata Tests Finished: %d PASS ---" % passes)
	return passes


func test_weapon_schemas_and_registries() -> int:
	var weapon = _make_weapon()
	var family_registry := InteractionFamilyRegistryScript.new()
	var family_ok := family_registry.register_family("rifle", "Rifle", ["two_hand", "muzzle"])
	var weapon_registry := WeaponRegistryScript.new()
	var profile := WeaponPoseProfileScript.new("pose_rifle", "Rifle Aim")
	profile.weapon_id = weapon.weapon_id
	var registry_ok := weapon_registry.register_weapon(weapon) and weapon_registry.register_profile(profile)
	var round_trip := WeaponDefinitionScript.new().from_dict(weapon.to_dict())
	if weapon.validate().is_empty() and family_ok and family_registry.supports("rifle", "muzzle") and registry_ok and round_trip.grips.size() == 2:
		print("  PASS: WPN schemas, interaction families, and asset registry serialize correctly")
		return 1
	printerr("  FAIL: WPN schema or registry validation failed")
	return 0


func test_dual_grip_editor_preview_and_alignment() -> int:
	var weapon = _make_weapon()
	var profile := WeaponPoseProfileScript.new("pose_rifle", "Rifle Aim")
	profile.weapon_id = weapon.weapon_id
	var grip_editor := GripEditorModelScript.new(weapon)
	grip_editor.set_transform("primary", Vector2.ZERO, 0.0)
	grip_editor.set_body_type_offset("secondary", "tall", Vector2(2.0, 0.0), 0.0)
	var editor := WeaponPosingEditorScript.new(weapon, profile)
	editor.set_weapon_transform(Vector2(30.0, 40.0), 0.0)
	var bindings_ok := editor.bind_hand_to_grip("primary", "upper_r", "lower_r", "hand_r", "fist")
	bindings_ok = bindings_ok and editor.bind_hand_to_grip("secondary", "upper_l", "lower_l", "hand_l", "support")
	var preview := editor.set_preview_context("tall")
	var rig := _make_arm_rig()
	var poses := HandPoseLibraryScript.new()
	var fist := HandPoseDefinitionScript.new("fist", "Fist")
	poses.add_pose(fist)
	var solve := editor.align_hands(rig, poses)
	var manager := BoneManagerScript.new()
	manager.initialize(rig)
	var hand_position := manager.get_global_transform("hand_r").origin
	var target := WeaponPoseSolverScript.resolve_grip_target(weapon, profile, "primary", "tall")
	if bindings_ok and preview.get("compatible", false) and preview.get("grips", []).size() == 2 and solve.get("success", false) and editor.get_solver_overlays().size() == 2 and int(editor.get_solver_instrumentation().get("arm_count", 0)) == 2 and hand_position.distance_to(target.get("position", Vector2.ZERO)) < 0.05:
		print("  PASS: Dual grips bind to hands and primary hand aligns to transformed weapon grip")
		return 1
	printerr("  FAIL: WPN dual-grip preview or arm alignment failed: %s" % str(solve))
	return 0


func test_action_point_and_collision_tracks() -> int:
	var point := ActionPointDefinitionScript.new("muzzle", "Muzzle")
	point.point_type = "muzzle"
	point.local_position = Vector2(0.0, 0.0)
	var action_track := ActionPointTrackScript.new("ap", "weapon", "action_point:muzzle")
	action_track.add_action_point_key(0.0, point, "ap0")
	point.local_position = Vector2(10.0, 0.0)
	action_track.add_action_point_key(1.0, point, "ap1")
	var at_half := action_track.evaluate_action_point(0.5)
	var hitbox := CollisionShapeDefinitionScript.new("slash", "Slash")
	hitbox.shape_type = CollisionShapeDefinitionScript.ShapeType.CAPSULE
	hitbox.size = Vector2(18.0, 48.0)
	hitbox.damage_region = "blade"
	var hit_track := CollisionShapeTrackScript.new("hit", "sword", "hitbox:blade", "hitbox")
	hit_track.add_shapes_key(0.2, [hitbox], "hit0")
	var hurt_track := CollisionShapeTrackScript.new("hurt", "hero", "hurtbox:torso", "hurtbox")
	hurt_track.add_shapes_key(0.0, [hitbox], "hurt0")
	var follower := CollisionShapeDefinitionScript.new("follower", "Bone Follower", CollisionShapeDefinitionScript.ShapeType.BONE_FOLLOWING)
	follower.bone_id = "upper_r"
	follower.local_position = Vector2(4.0, 0.0)
	var follower_position: Vector2 = follower.resolve_global_transform(_make_arm_rig()).get("position", Vector2.ZERO)
	if absf(float((at_half.get("local_position", [0.0, 0.0]) as Array)[0]) - 5.0) < 0.001 and hit_track.evaluate_shapes(0.3).size() == 1 and hit_track.validate().is_empty() and hurt_track.track_type == hurt_track.TrackType.HURTBOX and follower.validate().is_empty() and follower_position.is_equal_approx(Vector2(4.0, 0.0)):
		print("  PASS: Action points interpolate and keyframeable collision volumes evaluate")
		return 1
	printerr("  FAIL: Gameplay locator or collision track evaluation failed")
	return 0


func test_events_audio_visemes_and_parameters() -> int:
	var event_track := EventTrackScript.new("evt", "hero", "event:attack")
	event_track.add_event(0.25, "impact", "Impact", "notify", {"damage": 10})
	var audio_track := AudioCueTrackScript.new("audio", "hero", "audio:attack")
	audio_track.add_cue(0.25, "swing", "asset_swing", -3.0, 0.25)
	var viseme_track := VisemeTrackScript.new("vis", "face", "viseme:mouth")
	viseme_track.add_viseme(0.1, "AA", "mouth_aa", "v0")
	var parameter_track := ScriptParameterTrackScript.new("param", "hero", "script:damage", "damage", "number")
	parameter_track.add_parameter_key(0.0, 5, "p0")
	parameter_track.add_parameter_key(0.5, 10, "p1")
	var metadata := MetadataRegistryScript.new()
	metadata.add_track("attack", event_track)
	metadata.set_tag("combat", "Combat")
	metadata.set_variable("damage_scale", 1.5, "number")
	if event_track.get_events_between(0.0, 0.3).size() == 1 and audio_track.get_cues_between(0.0, 0.3).size() == 1 and viseme_track.evaluate_viseme(0.2).get("viseme_id") == "AA" and parameter_track.evaluate_value(0.75) == 10 and metadata.get_track_data("attack").size() == 1:
		print("  PASS: Events, audio cues, visemes, script parameters, tags, and variables are timeline data")
		return 1
	printerr("  FAIL: Gameplay event/audio/parameter track behavior failed")
	return 0


func test_specialized_track_round_trip() -> int:
	var original := EventTrackScript.new("evt", "hero", "event:attack")
	original.add_event(0.1, "start", "Start")
	var registry := TrackRegistryScript.new("clip")
	registry.add_track(original)
	var parameter := ScriptParameterTrackScript.new("param", "hero", "script:damage", "damage", "number")
	parameter.add_parameter_key(0.0, 10, "p0")
	registry.add_track(parameter)
	var restored := TrackRegistryScript.new("clip")
	var errors := restored.load_from_dict_array(registry.to_dict_array())
	var loaded = restored.get_track("evt")
	var loaded_parameter = restored.get_track("param")
	if errors.is_empty() and loaded != null and loaded.has_method("get_events_between") and loaded.get_events_between(0.0, 0.2).size() == 1 and loaded_parameter.parameter_name == "damage" and loaded_parameter.value_type == "number":
		print("  PASS: Timeline persistence restores specialized gameplay track behavior")
		return 1
	printerr("  FAIL: Specialized gameplay track did not round-trip")
	return 0


func _make_weapon():
	var weapon := WeaponDefinitionScript.new("rifle", "Training Rifle")
	weapon.asset_id = "asset_rifle"
	weapon.interaction_family_id = "rifle"
	weapon.supported_body_types = ["tall", "medium"]
	var primary := GripDefinitionScript.new("primary", "Trigger Grip", GripDefinitionScript.Role.PRIMARY)
	primary.hand_side = "right"
	var secondary := GripDefinitionScript.new("secondary", "Foregrip", GripDefinitionScript.Role.SECONDARY)
	secondary.hand_side = "left"
	secondary.local_position = Vector2(18.0, 0.0)
	weapon.add_grip(primary)
	weapon.add_grip(secondary)
	return weapon


func _make_arm_rig() -> Dictionary:
	var rig := RigSchemaScript.create_empty_rig("arm", "Arm Test Rig")
	var root := BoneSchemaScript.create_default_bone("root", "Root")
	var upper := BoneSchemaScript.create_default_bone("upper_r", "Upper Arm", "root")
	upper["length"] = 40.0
	var lower := BoneSchemaScript.create_default_bone("lower_r", "Lower Arm", "upper_r")
	lower["length"] = 30.0
	lower["local_position"] = Vector2(40.0, 0.0)
	var hand := BoneSchemaScript.create_default_bone("hand_r", "Hand", "lower_r")
	hand["local_position"] = Vector2(30.0, 0.0)
	var upper_left := BoneSchemaScript.create_default_bone("upper_l", "Upper Arm L", "root")
	upper_left["length"] = 40.0
	var lower_left := BoneSchemaScript.create_default_bone("lower_l", "Lower Arm L", "upper_l")
	lower_left["length"] = 30.0
	lower_left["local_position"] = Vector2(40.0, 0.0)
	var hand_left := BoneSchemaScript.create_default_bone("hand_l", "Hand L", "lower_l")
	hand_left["local_position"] = Vector2(30.0, 0.0)
	rig["bones"] = {
		"root": root, "upper_r": upper, "lower_r": lower, "hand_r": hand,
		"upper_l": upper_left, "lower_l": lower_left, "hand_l": hand_left
	}
	rig["root_bone_id"] = "root"
	return rig
