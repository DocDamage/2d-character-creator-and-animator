# Exercises legacy weapon posing and gameplay-metadata workflows end to end.
extends Node

const WeaponDefinitionScript = preload("res://weapons/definitions/weapon_definition.gd")
const GripDefinitionScript = preload("res://weapons/grips/grip_definition.gd")
const WeaponPoseProfileScript = preload("res://weapons/poses/weapon_pose_profile.gd")
const HandPoseDefinitionScript = preload("res://weapons/poses/hand_pose_definition.gd")
const HandPoseLibraryScript = preload("res://weapons/poses/hand_pose_library.gd")
const WeaponRegistryScript = preload("res://weapons/definitions/weapon_registry.gd")
const InteractionFamilyRegistryScript = preload("res://weapons/definitions/interaction_family_registry.gd")
const WeaponPosingEditorScript = preload("res://weapons/authoring/weapon_posing_editor.gd")
const WeaponPoseSolverScript = preload("res://weapons/solver/weapon_pose_solver.gd")
const BoneSchemaScript = preload("res://rigging/bones/bone_schema.gd")
const RigSchemaScript = preload("res://rigging/bones/rig_schema.gd")
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


func run_tests() -> Dictionary:
	var weapon: WeaponDefinition = _weapon()
	var profile: WeaponPoseProfile = _profile(weapon.weapon_id)
	var families = InteractionFamilyRegistryScript.new()
	var registry = WeaponRegistryScript.new()
	var families_ok: bool = families.register_family("rifle", "Rifle", ["two_hand", "muzzle"]) and families.supports("rifle", "muzzle")
	var registry_ok: bool = registry.register_weapon(weapon) and registry.register_profile(profile) and registry.get_profiles_for_weapon(weapon.weapon_id).size() == 1
	var poses = HandPoseLibraryScript.new()
	var right_pose: HandPoseDefinition = HandPoseDefinitionScript.new("right_fist", "Right Fist")
	right_pose.hand_side = "right"
	right_pose.wrist_rotation_offset = 0.1
	var left_pose: HandPoseDefinition = HandPoseDefinitionScript.new("left_support", "Left Support")
	left_pose.hand_side = "left"
	left_pose.bone_rotation_offsets = {"hand_l": -0.05}
	poses.add_pose(right_pose)
	poses.add_pose(left_pose)
	var editor = WeaponPosingEditorScript.new(weapon, profile)
	var bindings_ok: bool = editor.bind_hand_to_grip("primary", "upper_r", "lower_r", "hand_r", "right_fist") and editor.bind_hand_to_grip("secondary", "upper_l", "lower_l", "hand_l", "left_support")
	var preview: Dictionary = editor.set_preview_context("tall", "north", "shoot")
	var rig: Dictionary = _rig()
	var solve: Dictionary = editor.align_hands(rig, poses)
	var manager = BoneManagerScript.new()
	manager.initialize(rig)
	var primary_target := WeaponPoseSolverScript.resolve_grip_target(weapon, profile, "primary", "tall", "north", "shoot")
	var secondary_target := WeaponPoseSolverScript.resolve_grip_target(weapon, profile, "secondary", "tall", "north", "shoot")
	var incompatible: Dictionary = WeaponPoseSolverScript.solve_pose(_rig(), weapon, profile, poses, "small")
	var point: ActionPointDefinition = ActionPointDefinitionScript.new("muzzle", "Muzzle")
	point.point_type = "muzzle"
	point.bone_id = "hand_r"
	point.local_position = Vector2(2.0, 0.0)
	var point_track := ActionPointTrackScript.new("point", "weapon", "action:muzzle")
	point_track.add_action_point_key(0.0, point, "p0")
	point.local_position = Vector2(10.0, 0.0)
	point_track.add_action_point_key(1.0, point, "p1")
	var hitbox: CollisionShapeDefinition = CollisionShapeDefinitionScript.new("blade", "Blade", CollisionShapeDefinitionScript.ShapeType.CAPSULE)
	hitbox.size = Vector2(8.0, 24.0)
	hitbox.damage_region = "blade"
	var hurtbox: CollisionShapeDefinition = CollisionShapeDefinitionScript.new("torso", "Torso", CollisionShapeDefinitionScript.ShapeType.CONVEX_POLYGON)
	hurtbox.points = PackedVector2Array([Vector2(-2, -2), Vector2(2, -2), Vector2(0, 3)])
	var hit_track := CollisionShapeTrackScript.new("hit", "weapon", "hitbox:blade", "hitbox")
	var hurt_track := CollisionShapeTrackScript.new("hurt", "hero", "hurtbox:torso", "hurtbox")
	hit_track.add_shapes_key(0.2, [hitbox], "h0")
	hurt_track.add_shapes_key(0.0, [hurtbox], "u0")
	var events := EventTrackScript.new("events", "hero", "events:shoot")
	events.add_event(0.1, "muzzle_flash", "Muzzle Flash", "notify", {"weapon": weapon.weapon_id})
	events.add_event(0.2, "recoil", "Recoil")
	var audio := AudioCueTrackScript.new("audio", "hero", "audio:shoot")
	audio.add_cue(0.1, "shot", "asset_shot", -3.0, 2.0)
	var visemes := VisemeTrackScript.new("viseme", "hero", "viseme:mouth")
	visemes.add_viseme(0.1, "OO", "mouth_oo", "v0")
	var parameters := ScriptParameterTrackScript.new("parameter", "hero", "script:recoil", "recoil", "number")
	parameters.add_parameter_key(0.0, 0.0, "r0")
	parameters.add_parameter_key(0.2, 1.0, "r1")
	var metadata = MetadataRegistryScript.new()
	metadata.add_track("shoot", events)
	metadata.set_tag("combat", "Combat")
	metadata.set_variable("recoil_scale", 1.5, "number")
	var restored_metadata = MetadataRegistryScript.new()
	restored_metadata.from_dict(metadata.to_dict())
	var track_registry = TrackRegistryScript.new("shoot")
	for track in [point_track, hit_track, hurt_track, events, audio, visemes, parameters]:
		track_registry.add_track(track)
	var restored_tracks = TrackRegistryScript.new("shoot")
	var track_errors: Array = restored_tracks.load_from_dict_array(track_registry.to_dict_array())
	var midpoint: Dictionary = point_track.evaluate_action_point(0.5)
	var checks := {
		"weapon": weapon.validate().is_empty() and families_ok and registry_ok and WeaponDefinitionScript.new().from_dict(weapon.to_dict()).grips.size() == 2 and poses.find_for_side("right").size() == 1 and _round_trip_pose_count(poses) == 1,
		"dual_grip": bindings_ok and bool(preview.get("compatible", false)) and (preview.get("grips", []) as Array).size() == 2 and bool(solve.get("success", false)) and manager.get_global_transform("hand_r").origin.distance_to(primary_target.get("position", Vector2.ZERO)) < 0.05 and manager.get_global_transform("hand_l").origin.distance_to(secondary_target.get("position", Vector2.ZERO)) < 0.05 and not bool(incompatible.get("success", true)),
		"metadata": is_equal_approx(float((midpoint.get("local_position", [0.0, 0.0]) as Array)[0]), 6.0) and hit_track.evaluate_shapes(0.25).size() == 1 and hurt_track.evaluate_shapes(0.25).size() == 1 and hit_track.validate().is_empty() and hurt_track.validate().is_empty() and events.get_events_between(0.0, 0.2).size() == 2 and int((audio.get_cues_between(0.0, 0.2)[0] as Dictionary).get("pan", 0.0)) == 1 and visemes.evaluate_viseme(0.2).get("viseme_id") == "OO" and parameters.evaluate_value(0.1) == 0.0 and parameters.evaluate_value(0.2) == 1.0 and restored_metadata.get_track_data("shoot").size() == 1,
		"persistence": track_errors.is_empty() and restored_tracks.count() == 7 and restored_tracks.get_track("point").has_method("evaluate_action_point") and restored_tracks.get_track("hit").track_type == restored_tracks.get_track("hit").TrackType.HITBOX and restored_tracks.get_track("viseme").has_method("evaluate_viseme") and restored_tracks.get_track("parameter").parameter_name == "recoil",
	}
	if _all_true(checks):
		print("  PASS: Weapon definitions, dual-grip solve, gameplay metadata, and specialized-track persistence work together")
		return {"passed": 1, "failed": 0, "errors": []}
	return {"passed": 0, "failed": 1, "errors": ["Weapon/gameplay acceptance failed: %s" % checks]}


func _weapon() -> WeaponDefinition:
	var weapon: WeaponDefinition = WeaponDefinitionScript.new("rifle", "QA Rifle")
	weapon.asset_id = "asset_rifle"
	weapon.interaction_family_id = "rifle"
	weapon.supported_body_types = ["tall"]
	weapon.set_action_point("muzzle", {"name": "Muzzle"})
	weapon.sockets["holster"] = {"name": "Holster"}
	var primary: GripDefinition = GripDefinitionScript.new("primary", "Primary", GripDefinitionScript.Role.PRIMARY)
	primary.body_type_offsets["tall"] = {"position": [2.0, 0.0]}
	var secondary: GripDefinition = GripDefinitionScript.new("secondary", "Secondary", GripDefinitionScript.Role.SECONDARY)
	secondary.local_position = Vector2(16.0, 0.0)
	weapon.add_grip(primary)
	weapon.add_grip(secondary)
	return weapon


func _profile(weapon_id: String) -> WeaponPoseProfile:
	var profile: WeaponPoseProfile = WeaponPoseProfileScript.new("rifle_shoot", "Rifle Shoot")
	profile.weapon_id = weapon_id
	profile.base_position = Vector2(30.0, 20.0)
	profile.body_type_offsets["tall"] = {"position": [1.0, 0.0]}
	profile.direction_offsets["north"] = {"position": [0.0, -2.0]}
	profile.animation_offsets["shoot"] = {"rotation": 0.1}
	return profile


func _rig() -> Dictionary:
	var rig := RigSchemaScript.create_empty_rig("arms", "Arms")
	var bones: Dictionary = {}
	for side in ["r", "l"]:
		var upper := BoneSchemaScript.create_default_bone("upper_" + side, "Upper", "root")
		upper["length"] = 40.0
		var lower := BoneSchemaScript.create_default_bone("lower_" + side, "Lower", "upper_" + side)
		lower["length"] = 30.0
		lower["local_position"] = Vector2(40.0, 0.0)
		var hand := BoneSchemaScript.create_default_bone("hand_" + side, "Hand", "lower_" + side)
		hand["local_position"] = Vector2(30.0, 0.0)
		bones["upper_" + side] = upper
		bones["lower_" + side] = lower
		bones["hand_" + side] = hand
	bones["root"] = BoneSchemaScript.create_default_bone("root", "Root")
	rig["bones"] = bones
	rig["root_bone_id"] = "root"
	return rig


func _all_true(checks: Dictionary) -> bool:
	for value in checks.values():
		if not bool(value):
			return false
	return true


func _round_trip_pose_count(poses) -> int:
	var restored = HandPoseLibraryScript.new()
	restored.from_dict(poses.to_dict())
	return restored.find_for_side("right").size()
