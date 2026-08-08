# TestLpcPhase4 -- Acceptance for typed hybrid tracks, cels, deterministic replay/export, and missing-reference diagnostics.
class_name TestLpcPhase4
extends Node

const FixtureFactoryScript = preload("res://tests/lpc_phase_fixture_factory.gd")
const CatalogBuilderScript = preload("res://lpc/catalog/lpc_catalog_builder.gd")
const ProjectStoreScript = preload("res://lpc/project/lpc_project_store.gd")
const CreatorModelScript = preload("res://lpc/creator/lpc_creator_model.gd")
const PixelModelScript = preload("res://lpc/pixels/lpc_pixel_canvas_model.gd")
const ClipModelScript = preload("res://lpc/animation/lpc_clip_authoring_model.gd")
const AnimationPanelScript = preload("res://lpc/ui/lpc_animation_panel.gd")


func run_all_tests() -> Dictionary:
	var result := _exercise_hybrid_workflow()
	if bool(result.get("success", false)):
		print("  PASS: LPC phase 4 persists typed hybrid clips, replays cels/transforms/events, and exports deterministic frames")
		return {"passed": 1, "failed": 0, "errors": []}
	printerr("  FAIL: LPC phase 4 workflow failed: %s" % str(result.get("errors", [])))
	return {"passed": 0, "failed": 1, "errors": result.get("errors", [])}


func _exercise_hybrid_workflow() -> Dictionary:
	var root := "user://lpc_phase4_" + IDService.generate_short("hybrid"); var fixture := FixtureFactoryScript.create(root); var errors: Array[String] = []
	for error in fixture.get("errors", []): errors.append(str(error))
	if not bool(fixture.get("success", false)): return {"success": false, "errors": errors}
	var built := CatalogBuilderScript.build(str(fixture.get("source_root", ""))); if not bool(built.get("success", false)): errors.append_array(built.get("errors", []))
	var catalog: Dictionary = built.get("catalog", {}); var project_path := root.path_join("HybridRanger.chrproj")
	var created := ProjectStoreScript.create_new(project_path, {"catalog": catalog, "label": "Hybrid Ranger", "body_family_id": "human", "policy_id": "full_source"}) if errors.is_empty() else {}
	var opened := ProjectStoreScript.open(project_path, false) if bool(created.get("success", false)) else {}
	var creator = CreatorModelScript.new(); var bound := creator.bind_context(catalog, opened.get("profile", {}), opened.get("manifest", {}), project_path) if bool(opened.get("success", false)) else {}
	if bool(bound.get("success", false)): creator.select_asset("body_human"); creator.select_asset("shirt_blue"); creator.save()
	var pixel = PixelModelScript.new(); var source_loaded := pixel.open_native_frame(catalog, creator.profile, "base:body_human")
	if bool(source_loaded.get("success", false)):
		pixel.begin_stroke("Facial cel"); pixel.paint_pixel(Vector2i(4, 4), Color("ff00ff")); pixel.end_stroke()
	var cel_commit := pixel.commit_to_profile(creator.profile, {"target_id": "base:body_human", "frame": 0, "kind": "pixel_edit"}) if bool(source_loaded.get("success", false)) else {}
	var profile: Dictionary = cel_commit.get("profile", {}); var clip_model = ClipModelScript.new()
	var clip_bound := clip_model.bind_context(catalog, profile, creator.manifest, project_path) if not profile.is_empty() else {}
	var clip_created := clip_model.create_clip("Hybrid Walk", {"clip_id": "hybrid_walk", "duration": 0.3, "fps": 10.0, "default_animation_id": "walk", "default_direction_id": "down"}) if bool(clip_bound.get("success", false)) else {}
	var body_swap := clip_model.add_track("hybrid_walk", "image_cel_swap", "base:body_human") if bool(clip_created.get("success", false)) else {}
	if bool(body_swap.get("success", false)): clip_model.set_key("hybrid_walk", str((body_swap.get("track", {}) as Dictionary).get("track_id", "")), 0.0, {"derivative_id": str((cel_commit.get("derivative", {}) as Dictionary).get("derivative_id", ""))})
	var shirt_transform := clip_model.add_track("hybrid_walk", "layer_transform", "torso:shirt_blue") if bool(body_swap.get("success", false)) else {}
	if bool(shirt_transform.get("success", false)): clip_model.set_key("hybrid_walk", str((shirt_transform.get("track", {}) as Dictionary).get("track_id", "")), 0.0, {"position": [2, 0], "scale": [1, 1]})
	var source_track := clip_model.add_track("hybrid_walk", "source_frame", "torso:shirt_blue") if bool(shirt_transform.get("success", false)) else {}
	if bool(source_track.get("success", false)): clip_model.set_key("hybrid_walk", str((source_track.get("track", {}) as Dictionary).get("track_id", "")), 0.0, {"animation_id": "walk"})
	var z_track := clip_model.add_track("hybrid_walk", "z_order", "torso:shirt_blue") if bool(source_track.get("success", false)) else {}
	if bool(z_track.get("success", false)): clip_model.set_key("hybrid_walk", str((z_track.get("track", {}) as Dictionary).get("track_id", "")), 0.0, 11)
	var palette_track := clip_model.add_track("hybrid_walk", "palette", "torso:shirt_blue") if bool(z_track.get("success", false)) else {}
	if bool(palette_track.get("success", false)): clip_model.set_key("hybrid_walk", str((palette_track.get("track", {}) as Dictionary).get("track_id", "")), 0.0, {"mappings": {}})
	var shirt_visibility := clip_model.add_track("hybrid_walk", "visibility", "torso:shirt_blue") if bool(palette_track.get("success", false)) else {}
	if bool(shirt_visibility.get("success", false)):
		clip_model.set_key("hybrid_walk", str((shirt_visibility.get("track", {}) as Dictionary).get("track_id", "")), 0.0, true)
		clip_model.set_key("hybrid_walk", str((shirt_visibility.get("track", {}) as Dictionary).get("track_id", "")), 0.1, false)
	var event_track := clip_model.add_track("hybrid_walk", "event", "character") if bool(shirt_visibility.get("success", false)) else {}
	if bool(event_track.get("success", false)): clip_model.set_key("hybrid_walk", str((event_track.get("track", {}) as Dictionary).get("track_id", "")), 0.1, {"event_id": "footstep"})
	var direction_track := clip_model.add_track("hybrid_walk", "direction", "character") if bool(event_track.get("success", false)) else {}
	if bool(direction_track.get("success", false)): clip_model.set_key("hybrid_walk", str((direction_track.get("track", {}) as Dictionary).get("track_id", "")), 0.0, "down")
	var missing_rig := clip_model.add_track("hybrid_walk", "rig_bone_transform", "missing_bone") if bool(direction_track.get("success", false)) else {}
	if bool(missing_rig.get("success", false)): clip_model.set_key("hybrid_walk", str((missing_rig.get("track", {}) as Dictionary).get("track_id", "")), 0.0, {"rotation_degrees": 20.0})
	var missing_mesh := clip_model.add_track("hybrid_walk", "mesh_control", "missing_mesh") if bool(missing_rig.get("success", false)) else {}
	if bool(missing_mesh.get("success", false)): clip_model.set_key("hybrid_walk", str((missing_mesh.get("track", {}) as Dictionary).get("track_id", "")), 0.0, {"offset": [1, 0]})
	var invalid_track := clip_model.add_track("hybrid_walk", "arbitrary_script", "base:body_human")
	var first_preview := clip_model.preview("hybrid_walk", 0.0) if bool(missing_mesh.get("success", false)) else {}
	var second_preview := clip_model.preview("hybrid_walk", 0.15, 0.0) if bool(first_preview.get("success", false)) else {}
	var exported := clip_model.export_clip("hybrid_walk", root.path_join("hybrid_export")) if bool(second_preview.get("success", false)) else {}
	var saved := clip_model.save() if bool(exported.get("success", false)) else {}
	var reopened := ProjectStoreScript.open(project_path, false) if bool(saved.get("success", false)) else {}
	var replay_model = ClipModelScript.new(); var replay_bound := replay_model.bind_context(catalog, reopened.get("profile", {}), reopened.get("manifest", {}), project_path) if bool(reopened.get("success", false)) else {}
	var replay := replay_model.preview("hybrid_walk", 0.0) if bool(replay_bound.get("success", false)) else {}
	var panel = AnimationPanelScript.new(); add_child(panel); var panel_bound := panel.bind_context(catalog, profile, creator.manifest, project_path); panel.queue_free()
	var authored_types: Dictionary = {}
	for raw_track in (((clip_model.profile.get("clips", []) as Array)[0] as Dictionary).get("tracks", []) as Array): if raw_track is Dictionary: authored_types[str((raw_track as Dictionary).get("track_type", ""))] = true
	if not bool(created.get("success", false)) or not bool(source_loaded.get("success", false)) or not bool(cel_commit.get("success", false)): errors.append("Could not prepare a project-owned cel for hybrid playback.")
	if not bool(clip_created.get("success", false)) or not bool(body_swap.get("success", false)) or not bool(shirt_transform.get("success", false)) or not bool(source_track.get("success", false)) or not bool(z_track.get("success", false)) or not bool(palette_track.get("success", false)): errors.append("Typed clip or required tracks could not be authored.")
	for required_type in ["source_frame", "image_cel_swap", "layer_transform", "visibility", "z_order", "palette", "rig_bone_transform", "mesh_control", "event", "direction"]:
		if not authored_types.has(required_type): errors.append("Typed hybrid clip omitted '%s'." % required_type)
	if bool(invalid_track.get("success", true)): errors.append("Unknown executable LPC track types were accepted.")
	if not bool(first_preview.get("success", false)) or first_preview.get("image", null) == null or str((((first_preview.get("track_state", {}) as Dictionary).get("layers", {}) as Dictionary).get("base:body_human", {}) as Dictionary).get("cel_derivative_id", "")).is_empty(): errors.append("Hybrid preview did not resolve the project-owned cel against its stable layer ID.")
	if not bool(second_preview.get("success", false)) or bool((((second_preview.get("track_state", {}) as Dictionary).get("layers", {}) as Dictionary).get("torso:shirt_blue", {}) as Dictionary).get("visible", true)) or (second_preview.get("events", []) as Array).is_empty(): errors.append("Visibility and event tracks did not evaluate deterministically at the playhead.")
	var warnings: Array = second_preview.get("warnings", [])
	if warnings.filter(func(value): return str(value).contains("missing rig/bone")).is_empty() or warnings.filter(func(value): return str(value).contains("missing frame mesh")).is_empty(): errors.append("Missing rig/mesh track targets did not produce diagnostics.")
	if not bool(exported.get("success", false)) or int(exported.get("frame_count", 0)) != 3 or not FileAccess.file_exists(str(exported.get("manifest", ""))): errors.append("Hybrid exporter did not write replayable PNG artifacts and manifest.")
	if not bool(saved.get("success", false)) or not bool(reopened.get("success", false)) or (reopened.get("profile", {}).get("clips", []) as Array).size() != 1: errors.append("Typed clips did not survive save/reopen.")
	if not bool(replay.get("success", false)) or str(replay.get("output_hash", "")) != str(first_preview.get("output_hash", "")): errors.append("Reopened typed clip did not replay to the same verified output.")
	if not bool(panel_bound.get("success", false)): errors.append("The reachable Animate · Hybrid Clips panel could not bind the project context.")
	return {"success": errors.is_empty(), "errors": errors}
