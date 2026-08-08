# TestLpcPhase7 -- Acceptance for weighted LPC meshes, true cages, diagonal completion, and portable hybrid delivery.
class_name TestLpcPhase7
extends Node

const FixtureFactoryScript = preload("res://tests/lpc_phase_fixture_factory.gd")
const CatalogBuilderScript = preload("res://lpc/catalog/lpc_catalog_builder.gd")
const ProjectStoreScript = preload("res://lpc/project/lpc_project_store.gd")
const CreatorModelScript = preload("res://lpc/creator/lpc_creator_model.gd")
const RigModelScript = preload("res://lpc/rig/lpc_rig_workspace_model.gd")
const WeightMeshScript = preload("res://lpc/rig/lpc_weighted_mesh.gd")
const WeightPainterScript = preload("res://lpc/rig/lpc_weight_painter.gd")
const WeightEvaluatorScript = preload("res://lpc/rig/lpc_weighted_mesh_evaluator.gd")
const CageScript = preload("res://lpc/rig/lpc_cage_deformation.gd")
const ClipModelScript = preload("res://lpc/animation/lpc_clip_authoring_model.gd")
const DeliveryModelScript = preload("res://lpc/export/lpc_delivery_workspace_model.gd")
const DeliveryPanelScript = preload("res://lpc/ui/lpc_delivery_panel.gd")
const RuntimePlayerScript = preload("res://addons/modular_character_runtime/runtime/character_player_2d.gd")


func run_all_tests() -> Dictionary:
	var result := _exercise_production_delivery_workflow()
	if bool(result.get("success", false)):
		print("  PASS: LPC phase 7 weights, cages, authored diagonals, portable runtime, fallback, and clean consumer pass")
		return {"passed": 1, "failed": 0, "errors": []}
	printerr("  FAIL: LPC phase 7 workflow failed: %s" % [result.get("errors", [])])
	return {"passed": 0, "failed": 1, "errors": result.get("errors", [])}


func _exercise_production_delivery_workflow() -> Dictionary:
	var root := "user://lpc_phase7_" + IDService.generate_short("release")
	var errors: Array[String] = []
	var fixture := FixtureFactoryScript.create(root)
	var built := CatalogBuilderScript.build(str(fixture.get("source_root", ""))) if bool(fixture.get("success", false)) else {}
	var catalog: Dictionary = built.get("catalog", {})
	var project_path := root.path_join("ReleaseRanger.chrproj")
	var created := ProjectStoreScript.create_new(project_path, {"catalog": catalog, "label": "Release Ranger", "body_family_id": "human", "policy_id": "full_source"}) if bool(built.get("success", false)) else {}
	var opened := ProjectStoreScript.open(project_path, false) if bool(created.get("success", false)) else {}
	var creator = CreatorModelScript.new()
	var creator_bound := creator.bind_context(catalog, opened.get("profile", {}), opened.get("manifest", {}), project_path) if bool(opened.get("success", false)) else {}
	if bool(creator_bound.get("success", false)): creator.select_asset("body_human")
	var rig = RigModelScript.new()
	var bound := rig.bind_context(catalog, creator.profile, creator.manifest, project_path) if bool(creator_bound.get("success", false)) else {}
	var preparation_preview := rig.preview_preparation("base:body_human", {"source_direction_id": "down", "target_direction_id": "down"}) if bool(bound.get("success", false)) else {}
	var adapter_choices := rig.available_adapters("base:body_human", "down") if bool(bound.get("success", false)) else []
	var prepared := rig.prepare_for_rig("base:body_human", {"source_direction_id": "down", "target_direction_id": "down"}) if bool(bound.get("success", false)) else {}
	var down_adapter: Dictionary = prepared.get("adapter", {})
	var first_piece := str(((down_adapter.get("pieces", []) as Array)[0] as Dictionary).get("piece_id", "")) if not (down_adapter.get("pieces", []) as Array).is_empty() else ""
	var adjusted_piece := rig.update_piece(first_piece, {"pivot": [0, 0]}) if bool(prepared.get("success", false)) else {}
	var adjusted_anchor := rig.update_anchor("weapon", {"notes": "Validated release hand anchor"}) if bool(adjusted_piece.get("success", false)) else {}
	var weighted := rig.create_weighted_mesh(first_piece) if bool(prepared.get("success", false)) else {}
	var mesh: Dictionary = weighted.get("mesh", {})
	var initialized := rig.initialize_weights(str(mesh.get("mesh_id", "")), "distance_to_segment", {"max_influences": 2}) if bool(weighted.get("success", false)) else {}
	var painted := rig.paint_weights(str(mesh.get("mesh_id", "")), "head", Vector2(0, 0), {"mode": "ADD", "radius": 16.0, "strength": 0.25}) if bool(initialized.get("success", false)) else {}
	var smooth := rig.paint_weights(str(mesh.get("mesh_id", "")), "head", Vector2(0, 0), {"mode": "SMOOTH", "radius": 16.0, "strength": 1.0}) if bool(painted.get("success", false)) else {}
	var controls := rig.set_weighted_controls(str(mesh.get("mesh_id", "")), {"pins": [{"center": [0, 0], "offset": [1, 0], "radius": 8.0}], "soft_drags": [{"center": [64, 64], "offset": [0, 1], "radius": 8.0}]}) if bool(smooth.get("success", false)) else {}
	var cage := CageScript.create([[0, 0], [64, 0], [64, 64], [0, 64]], {"vertices": [[0, 0], [64, 0], [66, 64], [0, 64]]})
	var caged := rig.set_cage(str(mesh.get("mesh_id", "")), cage) if bool(controls.get("success", false)) else {}
	var order := rig.set_weighted_evaluation_order(str(mesh.get("mesh_id", "")), ["cage", "pins", "soft_drags", "bones", "vertex_offsets"]) if bool(caged.get("success", false)) else {}
	var smooth_fixture := WeightMeshScript.create({
		"mesh_id": "smooth_fixture", "rig_adapter_id": "fixture",
		"rest_vertices": [[0, 0], [10, 0], [0, 10]], "uvs": [[0, 0], [10, 0], [0, 10]],
		"triangle_indices": [0, 1, 2],
		"weights": [[{"bone_id": "head", "weight": 1.0}], [{"bone_id": "root", "weight": 1.0}], [{"bone_id": "root", "weight": 1.0}]],
	})
	var smoothed_fixture := WeightPainterScript.apply_stroke(smooth_fixture, "root", Vector2(0, 0), {"mode": "SMOOTH", "radius": 1.0, "strength": 1.0})
	var cage_center := CageScript.deform_position(cage, Vector2(32, 32))
	var evaluated_mesh := WeightEvaluatorScript.evaluate(order.get("mesh", {}) as Dictionary, _identity_bone_deltas(down_adapter)) if bool(order.get("success", false)) else {}
	var direction_enabled := rig.enable_eight_directions({"mirror_policy": {"allowed": false, "editable": true}}) if bool(order.get("success", false)) else {}
	var source_derivative := str(((down_adapter.get("pieces", []) as Array)[0] as Dictionary).get("derivative_id", "")) if not (down_adapter.get("pieces", []) as Array).is_empty() else ""
	var authored_cel := rig.author_direction("down_right", "CUSTOM_CEL", {"derivative_id": source_derivative}) if bool(direction_enabled.get("success", false)) else {}
	var diagonal_ids := ["down_left", "up_left", "up_right"]
	var diagonal_results: Array = []
	for direction_id in diagonal_ids:
		var converted := rig.prepare_for_rig("base:body_human", {"source_direction_id": "down", "target_direction_id": direction_id, "instance_id": "rig:base:body_human:" + direction_id})
		diagonal_results.append(converted)
		if bool(converted.get("success", false)): diagonal_results.append(rig.author_direction(direction_id, "RIGGED", {"adapter_instance_id": str((converted.get("adapter", {}) as Dictionary).get("instance_id", ""))}))
	var reopened_down := rig.open_adapter(str(down_adapter.get("instance_id", "")))
	var strategy := rig.set_layer_strategy("base:body_human", "RIGID_CUTOUT", "down") if bool(reopened_down.get("success", false)) else {}
	var clips = ClipModelScript.new()
	var clip_bound := clips.bind_context(catalog, rig.profile, rig.manifest, project_path) if bool(strategy.get("success", false)) else {}
	var clip_created := clips.create_clip("Release Pose", {"clip_id": "release_pose", "duration": 0.2, "fps": 10.0, "default_animation_id": "walk", "default_direction_id": "down"}) if bool(clip_bound.get("success", false)) else {}
	rig.profile = clips.profile.duplicate(true)
	var delivery = DeliveryModelScript.new()
	var delivery_bound := delivery.bind_context(catalog, rig.profile, rig.manifest, project_path) if bool(clip_created.get("success", false)) else {}
	var editable := delivery.export_delivery("EDITABLE_GODOT_RUNTIME", root.path_join("editable"), {"clip_id": "release_pose"}) if bool(delivery_bound.get("success", false)) else {}
	var hybrid := delivery.export_delivery("HYBRID_RUNTIME", root.path_join("hybrid"), {"clip_id": "release_pose"}) if bool(delivery_bound.get("success", false)) else {}
	var off_tree_runtime := _off_tree_runtime(str(hybrid.get("runtime_package", ""))) if bool(hybrid.get("success", false)) else {}
	var release_candidate := delivery.assess_release_candidate({"clip_id": "release_pose", "required_fixture_ids": ["cutout", "weighted", "clean_consumer"], "fixture_matrix": {"cutout": true, "weighted": true, "clean_consumer": true}}) if bool(hybrid.get("success", false)) else {}
	var saved := delivery.save() if bool(hybrid.get("success", false)) else {}
	var clean := _clean_consumer(root.path_join("hybrid")) if bool(hybrid.get("success", false)) else {"success": false, "errors": ["Hybrid delivery did not run."]}
	var panel = DeliveryPanelScript.new(); add_child(panel); var panel_bound := panel.bind_context(catalog, delivery.profile, delivery.manifest, project_path); panel.queue_free()
	if not bool(preparation_preview.get("success", false)) or adapter_choices.is_empty() or not bool(adjusted_piece.get("success", false)) or not bool(adjusted_anchor.get("success", false)): errors.append("Prepare-for-Rig preview, compatible/manual adapter choice, or editable cutout controls failed.")
	if not bool(weighted.get("success", false)) or not bool(initialized.get("success", false)) or not bool(painted.get("success", false)) or not bool(smooth.get("success", false)) or not bool(controls.get("success", false)) or not bool(caged.get("success", false)): errors.append("Weighted mesh creation, named initialization, atomic paint modes, controls, or cage persistence failed.")
	var smoothed_weight := 0.0
	for influence in ((smoothed_fixture.get("mesh", {}) as Dictionary).get("weights", [])[0] as Array): if str((influence as Dictionary).get("bone_id", "")) == "root": smoothed_weight = float((influence as Dictionary).get("weight", 0.0))
	if smoothed_weight <= 0.0: errors.append("Smooth weight painting did not use actual topology-neighbor influences.")
	if cage_center.x <= 32.0 or not bool(order.get("success", false)) or not bool(evaluated_mesh.get("success", false)) or (evaluated_mesh.get("vertices", []) as Array).is_empty(): errors.append("True cage evaluation or explicit cage/pin/soft/bone/direct order was not active.")
	var completed := (direction_enabled.get("completion", {}) as Dictionary)
	if not bool(authored_cel.get("success", false)) or diagonal_results.any(func(value): return value is Dictionary and not bool((value as Dictionary).get("success", false))) or not bool((rig.profile.get("direction_authoring", {}) as Dictionary).get("directions", {}).has("up_right")): errors.append("Explicit custom-cel and direction-specific rigged diagonal authoring failed.")
	if bool(editable.get("success", false)): errors.append("Editable runtime export accepted unsupported cage/soft-capable state without requiring an explicit fallback profile.")
	if not bool(hybrid.get("success", false)) or not FileAccess.file_exists(str(hybrid.get("manifest", ""))) or not FileAccess.file_exists(str(hybrid.get("runtime_package", ""))) or not FileAccess.file_exists(str(hybrid.get("runtime_resource", ""))) or not FileAccess.file_exists(str(hybrid.get("runtime_scene", ""))): errors.append("Hybrid runtime delivery did not write a portable manifest, editable runtime package, resource, and scene.")
	if not bool(off_tree_runtime.get("success", false)): errors.append_array(off_tree_runtime.get("errors", ["Portable runtime could not load while off-tree."]))
	if not bool(release_candidate.get("success", false)) or bool(release_candidate.get("release_ready", false)) or not str((release_candidate.get("warnings", []) as Array)[0] if not (release_candidate.get("warnings", []) as Array).is_empty() else "").contains("Human visual review"): errors.append("Release-candidate assessment did not preserve the required pending human-review gate.")
	var package_text := FileAccess.get_file_as_string(str(hybrid.get("runtime_package", "")))
	if package_text.contains("C:\\") or package_text.contains("file://"): errors.append("Editable runtime package leaked a developer absolute path.")
	if not bool(saved.get("success", false)) or not bool(clean.get("success", false)): errors.append_array(clean.get("errors", ["Delivery save or clean-consumer replay failed."]))
	if not bool(panel_bound.get("success", false)): errors.append("The reachable Deliver · LPC Runtime panel could not bind project context.")
	return {"success": errors.is_empty(), "errors": errors}


func _identity_bone_deltas(adapter: Dictionary) -> Dictionary:
	var output: Dictionary = {}
	for bone_id in (adapter.get("bones", {}) as Dictionary): output[str(bone_id)] = Transform2D.IDENTITY
	return output


func _off_tree_runtime(package_path: String) -> Dictionary:
	if package_path.is_empty() or not FileAccess.file_exists(package_path): return {"success": false, "errors": ["Runtime package is unavailable for off-tree replay."]}
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(package_path)) != OK or not json.get_data() is Dictionary: return {"success": false, "errors": ["Runtime package JSON is malformed."]}
	var player = RuntimePlayerScript.new()
	var loaded := player.load_package({"content": json.get_data() as Dictionary})
	var debug := player.get_debug_snapshot()
	player.free()
	return {"success": loaded and not (debug.get("bones", []) as Array).is_empty(), "errors": [] if loaded and not (debug.get("bones", []) as Array).is_empty() else ["Off-tree portable runtime replay failed: " + str(debug)]}


func _clean_consumer(root: String) -> Dictionary:
	var project_file := FileAccess.open(root.path_join("project.godot"), FileAccess.WRITE)
	if project_file == null: return {"success": false, "errors": ["Could not create clean-consumer project settings."]}
	project_file.store_string("[application]\nconfig/name=\"LPC Clean Consumer\"\n[rendering]\nrenderer/rendering_method=\"gl_compatibility\"\n")
	project_file.close()
	var script_file := FileAccess.open(root.path_join("test_lpc_consumer.gd"), FileAccess.WRITE)
	if script_file == null: return {"success": false, "errors": ["Could not create clean-consumer verification script."]}
	var consumer_script := """
extends SceneTree
const Importer = preload("res://addons/modular_character_runtime/runtime/chrproj_importer.gd")
const Player = preload("res://addons/modular_character_runtime/runtime/character_player_2d.gd")
func _fail(message: String) -> void:
 printerr(message)
 quit(1)
func _init() -> void:
 var missing = Importer.new().import_file("res://missing.chrproj", "res://missing.tres")
 if bool(missing.get("success", false)) or not "not found" in str(missing.get("errors", [])):
  _fail("MISSING_ASSET_DIAGNOSTIC_FAIL"); return
 var imported = Importer.new().import_file("res://lpc_runtime.chrproj", "res://hero.tres")
 if not bool(imported.get("success", false)):
  _fail("IMPORT_FAIL"); return
 var resource = load("res://lpc_runtime.tres")
 var packed_scene = load("res://lpc_character.tscn")
 if resource == null or packed_scene == null:
  _fail("RUNTIME_RESOURCE_FAIL"); return
 var player = Player.new()
 root.add_child(player)
 var loaded = player.load_runtime_data(resource)
 var debug = player.get_debug_snapshot()
 var nodes: Dictionary = debug.get("runtime_nodes", {})
 if not loaded or (debug.get("bones", []) as Array).is_empty() or int(nodes.get("sprites", 0)) + int(nodes.get("meshes", 0)) <= 0:
  _fail("PLAY_FAIL"); return
 for direction_id in ["up", "up_right", "right", "down_right", "down", "down_left", "left", "up_left"]:
  var facing = player.set_direction_id(direction_id)
  if not bool(facing.get("valid", false)) or str(facing.get("primary_direction", "")) != direction_id:
   _fail("DIRECTION_FAIL"); return
 var content: Dictionary = resource.get_content()
 for raw_clip in content.get("clips", []) as Array:
  if raw_clip is Dictionary and not player.play_runtime_clip(str((raw_clip as Dictionary).get("clip_id", ""))):
   _fail("CLIP_FAIL"); return
 player.equip("base", {"asset_id": "body_human"})
 debug = player.get_debug_snapshot()
 if not (debug.get("equipment", {}) as Dictionary).has("base") or not bool((debug.get("baked_fallback", {}) as Dictionary).get("available", false)) or (player.get_credits() as Dictionary).is_empty():
  _fail("DELIVERY_METADATA_FAIL"); return
 print("LPC_CLEAN_CONSUMER_PASS")
 quit(0)
"""
	script_file.store_string(consumer_script)
	script_file.close()
	var editor_output: Array = []; var restart_output: Array = []; var runtime_output: Array = []; var absolute := ProjectSettings.globalize_path(root)
	var editor_exit := OS.execute(OS.get_executable_path(), PackedStringArray(["--headless", "--path", absolute, "--editor", "--quit"]), editor_output, true)
	var restart_exit := OS.execute(OS.get_executable_path(), PackedStringArray(["--headless", "--path", absolute, "--editor", "--quit"]), restart_output, true)
	var runtime_exit := OS.execute(OS.get_executable_path(), PackedStringArray(["--headless", "--path", absolute, "--script", "res://test_lpc_consumer.gd"]), runtime_output, true)
	var output := "\n".join(runtime_output)
	return {"success": editor_exit == 0 and restart_exit == 0 and runtime_exit == 0 and "LPC_CLEAN_CONSUMER_PASS" in output, "errors": [] if editor_exit == 0 and restart_exit == 0 and runtime_exit == 0 and "LPC_CLEAN_CONSUMER_PASS" in output else ["Clean consumer output: " + output]}
