# TestLpcPhase5 -- Acceptance for strict per-frame LPC deformation, bake artifacts, persistence, and hybrid parity.
class_name TestLpcPhase5
extends Node

const FixtureFactoryScript = preload("res://tests/lpc_phase_fixture_factory.gd")
const CatalogBuilderScript = preload("res://lpc/catalog/lpc_catalog_builder.gd")
const ProjectStoreScript = preload("res://lpc/project/lpc_project_store.gd")
const ProjectProfileScript = preload("res://lpc/project/lpc_project_profile.gd")
const CreatorModelScript = preload("res://lpc/creator/lpc_creator_model.gd")
const WorkspaceModelScript = preload("res://lpc/deformation/lpc_deformation_workspace_model.gd")
const MeshFactoryScript = preload("res://lpc/deformation/lpc_frame_mesh_factory.gd")
const BakerScript = preload("res://lpc/deformation/lpc_strict_frame_baker.gd")
const DiagnosticsScript = preload("res://lpc/deformation/lpc_deformation_diagnostics.gd")
const ClipModelScript = preload("res://lpc/animation/lpc_clip_authoring_model.gd")
const DeformPanelScript = preload("res://lpc/ui/lpc_deform_panel.gd")


func run_all_tests() -> Dictionary:
	var result := _exercise_strict_warp_workflow()
	if bool(result.get("success", false)):
		print("  PASS: LPC phase 5 persists frame-bound strict warps with deterministic PNG bake/export parity")
		return {"passed": 1, "failed": 0, "errors": []}
	printerr("  FAIL: LPC phase 5 workflow failed: %s" % str(result.get("errors", [])))
	return {"passed": 0, "failed": 1, "errors": result.get("errors", [])}


func _exercise_strict_warp_workflow() -> Dictionary:
	var root := "user://lpc_phase5_" + IDService.generate_short("warp")
	var errors: Array[String] = []
	var fixture := FixtureFactoryScript.create(root)
	if not bool(fixture.get("success", false)): errors.append_array(fixture.get("errors", []))
	var built := CatalogBuilderScript.build(str(fixture.get("source_root", ""))) if errors.is_empty() else {}
	if not bool(built.get("success", false)): errors.append_array(built.get("errors", []))
	var catalog: Dictionary = built.get("catalog", {})
	var project_path := root.path_join("WarpRanger.chrproj")
	var created := ProjectStoreScript.create_new(project_path, {"catalog": catalog, "label": "Warp Ranger", "body_family_id": "human", "policy_id": "full_source"}) if errors.is_empty() else {}
	var opened := ProjectStoreScript.open(project_path, false) if bool(created.get("success", false)) else {}
	var creator = CreatorModelScript.new()
	var creator_bound := creator.bind_context(catalog, opened.get("profile", {}), opened.get("manifest", {}), project_path) if bool(opened.get("success", false)) else {}
	if bool(creator_bound.get("success", false)):
		creator.select_asset("body_human")
		creator.select_asset("shirt_blue")
		creator.save()
	var workspace = WorkspaceModelScript.new()
	var workspace_bound := workspace.bind_context(catalog, creator.profile, creator.manifest, project_path) if bool(creator_bound.get("success", false)) else {}
	var source_loaded := workspace.open_native_frame("base:body_human", "walk", "down", 0) if bool(workspace_bound.get("success", false)) else {}
	var source_bytes: PackedByteArray = workspace.source.get_data() if bool(source_loaded.get("success", false)) else PackedByteArray()
	var created_mesh := workspace.create_mesh("rectangular_grid", {"mesh_id": "body_walk_down_0", "columns": 4, "rows": 4}) if bool(source_loaded.get("success", false)) else {}
	var moved := workspace.move_vertex(6, Vector2(1, 0)) if bool(created_mesh.get("success", false)) else {}
	var pinned := workspace.add_pin(Vector2(32, 32), Vector2.ZERO, 20.0) if bool(moved.get("success", false)) else {}
	var latticed := workspace.set_lattice({"origin": [0, 0], "size": [64, 64], "columns": 2, "rows": 2, "offsets": {"0:0": [0, 0], "1:0": [0, 0], "0:1": [0, 0], "1:1": [0, 0]}}) if bool(pinned.get("success", false)) else {}
	var dragged := workspace.add_soft_drag(Vector2(32, 32), Vector2(32, 32), 16.0) if bool(latticed.get("success", false)) else {}
	var mesh: Dictionary = workspace.active_mesh()
	var interactive := workspace.interactive_preview() if bool(dragged.get("success", false)) else {}
	var verified_path := root.path_join("strict/verified.png")
	var verified := workspace.verify(verified_path) if bool(interactive.get("success", false)) else {}
	var repeat := workspace.verify(root.path_join("strict/repeat.png")) if bool(verified.get("success", false)) else {}
	var exported := workspace.export_strict(root.path_join("export"), {"filename": "body_warp.png"}) if bool(repeat.get("success", false)) else {}
	var saved := workspace.save() if bool(exported.get("success", false)) else {}
	var autosaved := workspace.autosave() if bool(saved.get("success", false)) else {}
	var reopened := ProjectStoreScript.open(project_path, false) if bool(saved.get("success", false)) else {}
	var replay = WorkspaceModelScript.new()
	var replay_bound := replay.bind_context(catalog, reopened.get("profile", {}), reopened.get("manifest", {}), project_path) if bool(reopened.get("success", false)) else {}
	var reopened_mesh := replay.open_mesh("body_walk_down_0") if bool(replay_bound.get("success", false)) else {}
	var replay_bake := replay.verify(root.path_join("strict/reopened.png")) if bool(reopened_mesh.get("success", false)) else {}
	var changed_source: Image = workspace.source.duplicate() if workspace.source != null else null
	if changed_source != null: changed_source.set_pixel(0, 0, Color("00ff00"))
	var wrong_source := BakerScript.bake(mesh, changed_source, {"source_asset_id": "body_human", "source_asset_sha256": str((catalog.get("assets", {}) as Dictionary).get("body_human", {}).get("source_sha256", ""))}) if changed_source != null else {}
	var flipped_mesh := mesh.duplicate(true)
	flipped_mesh["control_state"] = {"vertex_offsets": {"0": [50, 50]}, "pins": [], "lattice": {}, "soft_drags": []}
	var flipped := BakerScript.bake(flipped_mesh, workspace.source, {"source_asset_id": "body_human", "source_asset_sha256": str((catalog.get("assets", {}) as Dictionary).get("body_human", {}).get("source_sha256", ""))}) if workspace.source != null else {}
	var alpha_result := _exercise_alpha_and_manual_meshes()
	var clip_result := _exercise_hybrid_mesh_track(catalog, workspace, project_path)
	var legacy: Dictionary = workspace.profile.duplicate(true)
	legacy["profile_schema_version"] = "1.2.0"
	legacy.erase("deformation_workspace_state")
	var migrated := ProjectProfileScript.migrate(legacy)
	var panel = DeformPanelScript.new()
	add_child(panel)
	var panel_bound := panel.bind_context(catalog, workspace.profile, workspace.manifest, project_path)
	panel.queue_free()
	if not bool(created.get("success", false)) or not bool(creator_bound.get("success", false)) or not bool(workspace_bound.get("success", false)):
		errors.append("Could not create and bind the strict-frame deformation project workflow.")
	if not bool(source_loaded.get("success", false)) or not bool(created_mesh.get("success", false)):
		errors.append("Could not open a source-bound native frame and create a rectangular mesh.")
	if not bool(moved.get("success", false)) or not bool(pinned.get("success", false)) or not bool(latticed.get("success", false)) or not bool(dragged.get("success", false)):
		errors.append("Direct, radial pin, bilinear lattice, and soft-drag controls were not all available as commands.")
	var controls: Dictionary = mesh.get("control_state", {})
	if (controls.get("vertex_offsets", {}) as Dictionary).is_empty() or (controls.get("pins", []) as Array).is_empty() or (controls.get("lattice", {}) as Dictionary).is_empty() or (controls.get("soft_drags", []) as Array).is_empty():
		errors.append("Strict frame-mesh controls did not persist their independent non-destructive state.")
	if workspace.source == null or workspace.source.get_data() != source_bytes:
		errors.append("Frame deformation mutated the immutable LPC source image.")
	if not bool(interactive.get("success", false)) or bool(interactive.get("verified", true)):
		errors.append("Interactive frame-warp preview was not clearly labeled as unverified.")
	if not bool(verified.get("success", false)) or not bool(verified.get("deterministic", false)) or int(verified.get("audit", {}).get("outside_source_color_count", 1)) != 0 or int(verified.get("audit", {}).get("new_partial_alpha_pixels", 1)) != 0:
		errors.append("Verified strict bake did not prove deterministic source-color and alpha invariants.")
	if not FileAccess.file_exists(verified_path) or not FileAccess.file_exists(verified_path.get_basename() + ".audit.json"):
		errors.append("Strict bake did not write the required PNG and audit artifact.")
	if not bool(repeat.get("success", false)) or str(repeat.get("output_hash", "")) != str(verified.get("output_hash", "")):
		errors.append("Repeated strict bakes did not produce the same hash.")
	var exported_bake: Dictionary = exported.get("bake", {})
	var exported_image := Image.load_from_file(str(exported.get("output_path", ""))) if bool(exported.get("success", false)) else null
	if not bool(exported.get("success", false)) or not FileAccess.file_exists(str(exported.get("manifest", ""))) or exported_image == null or DiagnosticsScript.image_hash(exported_image) != str(exported_bake.get("output_hash", "")):
		errors.append("Strict-warp export did not produce a replayable PNG whose content matches its verified bake hash.")
	if not bool(saved.get("success", false)) or not bool(autosaved.get("success", false)) or not bool(reopened.get("success", false)) or not bool(replay_bake.get("success", false)) or str(replay_bake.get("output_hash", "")) != str(verified.get("output_hash", "")):
		errors.append("Frame mesh, control state, bake cache, save/reopen, or autosave recovery did not preserve deterministic output.")
	if bool(wrong_source.get("success", true)) or bool(flipped.get("success", true)):
		errors.append("Changed source binding or flipped triangle was not rejected as a hard strict-bake failure.")
	if not bool(alpha_result.get("success", false)): errors.append_array(alpha_result.get("errors", []))
	if not bool(clip_result.get("success", false)): errors.append_array(clip_result.get("errors", []))
	if not bool(migrated.get("success", false)) or str((migrated.get("profile", {}) as Dictionary).get("profile_schema_version", "")) != "1.3.0":
		errors.append("LPC profile migration did not add deformation workspace state at schema 1.3.0.")
	if not bool(panel_bound.get("success", false)):
		errors.append("The reachable Deform · Strict Frame Warp panel could not bind project context.")
	return {"success": errors.is_empty(), "errors": errors}


func _exercise_alpha_and_manual_meshes() -> Dictionary:
	var errors: Array[String] = []
	var image := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	for y in range(1, 6):
		for x in range(1, 6):
			if x != 3 or y != 3: image.set_pixel(x, y, Color("ff8800"))
	image.set_pixel(7, 0, Color("88ccff"))
	var context := {"source_asset_id": "alpha_fixture", "source_hash": "synthetic-alpha", "source_frame_reference": {"animation_id": "walk", "direction_id": "down", "logical_frame_index": 0}}
	var alpha := MeshFactoryScript.alpha_aware(image, context)
	var alpha_mesh: Dictionary = alpha.get("mesh", {})
	var alpha_bake := BakerScript.bake(alpha_mesh, image, {"source_asset_id": "alpha_fixture", "source_asset_sha256": "synthetic-alpha"}) if bool(alpha.get("success", false)) else {}
	var manual := MeshFactoryScript.manual(context, [Vector2(0, 0), Vector2(4, 0), Vector2(0, 4)], [Vector2(0, 0), Vector2(4, 0), Vector2(0, 4)], [0, 1, 2], {"mesh_id": "manual_fixture", "source": image})
	if not bool(alpha.get("success", false)) or int((alpha_mesh.get("provenance", {}) as Dictionary).get("island_count", 0)) != 2 or (alpha_mesh.get("hole_records", []) as Array).is_empty():
		errors.append("Alpha-aware mesh did not preserve disconnected islands and its internal transparent hole.")
	if not bool(alpha_bake.get("success", false)) or int((alpha_bake.get("diagnostics", {}).get("metrics", {}) as Dictionary).get("output_opaque_pixels", -1)) != int((alpha_bake.get("diagnostics", {}).get("metrics", {}) as Dictionary).get("source_opaque_pixels", -2)):
		errors.append("Alpha-aware strict bake did not cover every required opaque fixture pixel without cracks.")
	if not bool(manual.get("success", false)):
		errors.append("Manual frame-mesh topology was not validated and accepted.")
	return {"success": errors.is_empty(), "errors": errors}


func _exercise_hybrid_mesh_track(catalog: Dictionary, workspace, project_path: String) -> Dictionary:
	var errors: Array[String] = []
	var clips = ClipModelScript.new()
	var bound := clips.bind_context(catalog, workspace.profile, workspace.manifest, project_path)
	var created := clips.create_clip("Warp Clip", {"clip_id": "warp_clip", "duration": 0.1, "fps": 10.0, "default_animation_id": "walk", "default_direction_id": "down"}) if bool(bound.get("success", false)) else {}
	var track := clips.add_track("warp_clip", "mesh_control", "body_walk_down_0") if bool(created.get("success", false)) else {}
	var keyed := clips.set_key("warp_clip", str((track.get("track", {}) as Dictionary).get("track_id", "")), 0.0, workspace.active_mesh().get("control_state", {})) if bool(track.get("success", false)) else {}
	var preview := clips.preview("warp_clip", 0.0) if bool(keyed.get("success", false)) else {}
	var mesh_recorded := false
	for record in preview.get("layers", []):
		if record is Dictionary and str((record as Dictionary).get("mesh_id", "")) == "body_walk_down_0": mesh_recorded = true
	if not bool(preview.get("success", false)) or not mesh_recorded:
		errors.append("Typed mesh-control track did not execute the frame-bound strict bake during hybrid playback.")
	return {"success": errors.is_empty(), "errors": errors}
