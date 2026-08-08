# TestLpcPhase6 -- Acceptance for direction-specific project-owned cutouts, rigid posing, gaps, persistence, and hybrid clips.
class_name TestLpcPhase6
extends Node

const FixtureFactoryScript = preload("res://tests/lpc_phase_fixture_factory.gd")
const CatalogBuilderScript = preload("res://lpc/catalog/lpc_catalog_builder.gd")
const ProjectStoreScript = preload("res://lpc/project/lpc_project_store.gd")
const ProfileScript = preload("res://lpc/project/lpc_project_profile.gd")
const CreatorModelScript = preload("res://lpc/creator/lpc_creator_model.gd")
const RigModelScript = preload("res://lpc/rig/lpc_rig_workspace_model.gd")
const ClipModelScript = preload("res://lpc/animation/lpc_clip_authoring_model.gd")
const RigPanelScript = preload("res://lpc/ui/lpc_rig_panel.gd")


func run_all_tests() -> Dictionary:
	var result := _exercise_cutout_rig_workflow()
	if bool(result.get("success", false)):
		print("  PASS: LPC phase 6 creates persistent project-owned cutouts, rigid poses, anchors, fallback, and hybrid playback")
		return {"passed": 1, "failed": 0, "errors": []}
	printerr("  FAIL: LPC phase 6 workflow failed: %s" % [result.get("errors", [])])
	return {"passed": 0, "failed": 1, "errors": result.get("errors", [])}


func _exercise_cutout_rig_workflow() -> Dictionary:
	var root := "user://lpc_phase6_" + IDService.generate_short("rig")
	var errors: Array[String] = []
	var fixture := FixtureFactoryScript.create(root)
	var built := CatalogBuilderScript.build(str(fixture.get("source_root", ""))) if bool(fixture.get("success", false)) else {}
	var catalog: Dictionary = built.get("catalog", {})
	var project_path := root.path_join("CutoutRanger.chrproj")
	var created := ProjectStoreScript.create_new(project_path, {"catalog": catalog, "label": "Cutout Ranger", "body_family_id": "human", "policy_id": "full_source"}) if bool(built.get("success", false)) else {}
	var opened := ProjectStoreScript.open(project_path, false) if bool(created.get("success", false)) else {}
	var creator = CreatorModelScript.new()
	var creator_bound := creator.bind_context(catalog, opened.get("profile", {}), opened.get("manifest", {}), project_path) if bool(opened.get("success", false)) else {}
	if bool(creator_bound.get("success", false)):
		creator.select_asset("body_human")
		creator.select_asset("shirt_blue")
	var rig = RigModelScript.new()
	var bound := rig.bind_context(catalog, creator.profile, creator.manifest, project_path) if bool(creator_bound.get("success", false)) else {}
	var prepared := rig.prepare_for_rig("base:body_human", {"source_direction_id": "down", "target_direction_id": "down", "animation_id": "walk"}) if bool(bound.get("success", false)) else {}
	var source_bytes: PackedByteArray = rig.active_source.get_data() if rig.active_source != null else PackedByteArray()
	var adapter: Dictionary = prepared.get("adapter", {})
	var posed := rig.set_bone_pose("head", {"rotation_offset_degrees": 12.0}) if bool(prepared.get("success", false)) else {}
	var anchor := rig.solve_hand_to_anchor("hand_right", Vector2(57, 42)) if bool(posed.get("success", false)) else {}
	var gap := rig.repair_gap(Rect2i(0, 0, 4, 4), {"bone_id": "torso"}) if bool(anchor.get("success", false)) else {}
	var preview := rig.preview() if bool(gap.get("success", false)) else {}
	var clips = ClipModelScript.new()
	var clips_bound := clips.bind_context(catalog, rig.profile, rig.manifest, project_path) if bool(preview.get("success", false)) else {}
	var clip_created := clips.create_clip("Cutout Pose", {"clip_id": "cutout_pose", "duration": 0.2, "fps": 10.0, "default_animation_id": "walk", "default_direction_id": "down"}) if bool(clips_bound.get("success", false)) else {}
	var track := clips.add_track("cutout_pose", "rig_bone_transform", str(adapter.get("instance_id", "")) + ":head") if bool(clip_created.get("success", false)) else {}
	var keyed := clips.set_key("cutout_pose", str((track.get("track", {}) as Dictionary).get("track_id", "")), 0.0, {"rotation_offset_degrees": 8.0}) if bool(track.get("success", false)) else {}
	var hybrid := clips.preview("cutout_pose", 0.0) if bool(keyed.get("success", false)) else {}
	rig.profile = clips.profile.duplicate(true)
	var saved := rig.save() if bool(hybrid.get("success", false)) else {}
	var autosaved := rig.autosave() if bool(saved.get("success", false)) else {}
	var reopened := ProjectStoreScript.open(project_path, false) if bool(saved.get("success", false)) else {}
	var replay = RigModelScript.new()
	var replay_bound := replay.bind_context(catalog, reopened.get("profile", {}), reopened.get("manifest", {}), project_path) if bool(reopened.get("success", false)) else {}
	var replay_opened := replay.open_adapter(str(adapter.get("instance_id", ""))) if bool(replay_bound.get("success", false)) else {}
	var replay_preview := replay.preview() if bool(replay_opened.get("success", false)) else {}
	var legacy: Dictionary = rig.profile.duplicate(true); legacy["profile_schema_version"] = "1.3.0"; legacy.erase("rig_workspace_state"); legacy.erase("weighted_meshes")
	var migrated := ProfileScript.migrate(legacy)
	var panel = RigPanelScript.new(); add_child(panel); var panel_bound := panel.bind_context(catalog, rig.profile, rig.manifest, project_path); panel.queue_free()
	if not bool(prepared.get("success", false)) or (adapter.get("pieces", []) as Array).is_empty() or (rig.profile.get("rig_adapters", []) as Array).is_empty(): errors.append("Prepare for Rig did not create a persistent direction-specific cutout adapter and pieces.")
	if str((adapter.get("source_binding", {}) as Dictionary).get("source_hash", "")).is_empty() or not bool((prepared.get("command", {}) as Dictionary).get("reversible", false)): errors.append("Cutout rig preparation did not retain source provenance or a reversible command macro.")
	if not bool(posed.get("success", false)) or not bool(anchor.get("success", false)) or not bool(preview.get("success", false)) or preview.get("image", null) == null: errors.append("Rigid bone posing, two-bone hand anchor solving, or cutout preview failed: pose=%s anchor=%s gap=%s preview=%s" % [posed.get("errors", []), anchor.get("errors", []), gap.get("errors", []), preview.get("errors", [])])
	if not bool(gap.get("success", false)) or str((gap.get("derivative", {}) as Dictionary).get("operation", "")) != "rig_gap_patch": errors.append("Hidden-pixel gap repair did not create a project-owned patch derivative: %s" % [gap.get("errors", [])])
	if rig.active_source == null or rig.active_source.get_data() != source_bytes: errors.append("Prepare for Rig or posing mutated the immutable native source frame.")
	var rigged := false
	for record in hybrid.get("layers", []): if record is Dictionary and str((record as Dictionary).get("mode", "")) == "rigged_cutout": rigged = true
	if not bool(hybrid.get("success", false)) or not rigged: errors.append("Hybrid clip evaluation did not use the rigged cutout layer alongside native layers.")
	if not bool(saved.get("success", false)) or not bool(autosaved.get("success", false)) or not bool(replay_preview.get("success", false)): errors.append("Cutout rig save/reopen/autosave did not preserve an editable evaluated pose.")
	if not bool(migrated.get("success", false)) or str((migrated.get("profile", {}) as Dictionary).get("profile_schema_version", "")) != ProfileScript.PROFILE_SCHEMA_VERSION: errors.append("LPC profile migration did not add rig-ready state through the current schema.")
	if not bool(panel_bound.get("success", false)): errors.append("The reachable Rig · Cutouts & Weights panel could not bind project context.")
	return {"success": errors.is_empty(), "errors": errors}
