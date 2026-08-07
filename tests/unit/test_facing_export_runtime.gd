# Unit tests for directional grids, rules, export formats, and the runtime player.
extends Node

const FacingGridScript = preload("res://facing/facing_grid_definition.gd")
const FacingEvaluatorScript = preload("res://facing/facing_grid_evaluator.gd")
const StateMachineScript = preload("res://animation/state_machine/state_machine_definition.gd")
const StateEvaluatorScript = preload("res://animation/state_machine/state_machine_evaluator.gd")
const RuleGraphScript = preload("res://animation/rules/rule_graph.gd")
const RuntimePackageScript = preload("res://export/project_format/runtime_package.gd")
const RuntimeExporterScript = preload("res://export/project_format/runtime_package_exporter.gd")
const AtlasPackerScript = preload("res://export/atlases/texture_atlas_packer.gd")
const SpritesheetExporterScript = preload("res://export/spritesheets/spritesheet_exporter.gd")
const ImageSequenceExporterScript = preload("res://export/image_sequences/image_sequence_exporter.gd")
const GifExporterScript = preload("res://export/gif/gif_exporter.gd")
const VideoExporterScript = preload("res://export/video/video_exporter.gd")
const GodotExporterScript = preload("res://export/godot/godot_resource_exporter.gd")
const ChrprojImporterScript = preload("res://runtime_plugin/importer/chrproj_importer.gd")
const PortableChrprojImporterScript = preload("res://addons/modular_character_runtime/runtime/chrproj_importer.gd")
const CharacterPlayerScript = preload("res://runtime_plugin/player/character_player_2d.gd")
const ExportBatchTestsScript = preload("res://tests/integration/test_export_batch.gd")
const GodotRuntimeMappingTestsScript = preload("res://tests/integration/test_godot_runtime_mapping.gd")
const QualityReliabilityTestsScript = preload("res://tests/integration/test_quality_reliability.gd")
const ReleaseReadinessTestsScript = preload("res://tests/integration/test_release_readiness.gd")


func run_tests() -> int:
	print("--- Running Facing, Export & Runtime Tests ---")
	var passes := 0
	passes += test_facing_grid_selection_and_mesh_blending()
	passes += test_state_machine_and_rule_actions()
	passes += test_state_machine_speed_scale()
	passes += test_baked_and_runtime_exports()
	passes += test_importer_and_runtime_player()
	passes += test_portable_addon_importer()
	var export_batch_tests := ExportBatchTestsScript.new()
	passes += export_batch_tests.run_tests()
	export_batch_tests.free()
	var godot_runtime_mapping_tests := GodotRuntimeMappingTestsScript.new()
	passes += godot_runtime_mapping_tests.run_tests()
	godot_runtime_mapping_tests.free()
	var quality_reliability_tests := QualityReliabilityTestsScript.new()
	passes += quality_reliability_tests.run_tests()
	quality_reliability_tests.free()
	var release_readiness_tests := ReleaseReadinessTestsScript.new()
	passes += release_readiness_tests.run_tests()
	release_readiness_tests.free()
	print("--- Facing, Export & Runtime Tests Finished: %d PASS ---" % passes)
	return passes


func test_facing_grid_selection_and_mesh_blending() -> int:
	var grid := FacingGridScript.new("hero_grid", "Hero")
	grid.set_direction_set(FacingGridScript.DirectionSet.EIGHT_WAY)
	for direction_id in grid.get_direction_ids():
		grid.set_cell(direction_id, {"asset_id": "hero_" + direction_id})
	grid.set_cell("north", {"asset_id": "hero_north", "slot_swap": {"hand_left": "hand_right"}})
	var mirrored := grid.mirror_cell("north", "south", true)
	var north := FacingEvaluatorScript.evaluate(grid, Vector2.UP)
	var diagonal := FacingEvaluatorScript.evaluate(grid, Vector2(1, -0.5), FacingGridScript.BlendMode.CROSSFADE)
	var points := FacingEvaluatorScript.interpolate_mesh_vertices([Vector2.ZERO, Vector2(2, 0)], [Vector2(2, 2), Vector2(4, 0)], 0.5)
	var restored := FacingGridScript.new().from_dict(grid.to_dict())
	if mirrored and north.get("primary_direction") == "north" and diagonal.get("mode") == "crossfade" and points[0].is_equal_approx(Vector2(1, 1)) and restored.missing_directions().is_empty():
		print("  PASS: 4/8-way cells resolve, mirror, serialize, and mesh-blend deterministically")
		return 1
	printerr("  FAIL: Facing-grid direction evaluation failed")
	return 0


func test_state_machine_and_rule_actions() -> int:
	var machine := StateMachineScript.new("locomotion", "Locomotion")
	machine.add_state("idle", "idle")
	machine.add_state("run", "run")
	machine.add_state("attack", "attack")
	machine.set_state_property("attack", "loop", false)
	machine.add_parameter("speed", 0.0, "float")
	machine.add_parameter("attack", false, "trigger")
	machine.add_transition("idle_run", "idle", "run", [{"type": "parameter", "parameter": "speed", "operator": ">", "value": 0.1}])
	machine.add_transition("run_attack", "run", "attack", [{"type": "trigger", "parameter": "attack"}])
	var transition := machine.get_transition("idle_run")
	transition["duration"] = 0.25
	for index in range(machine.transitions.size()):
		if machine.transitions[index]["transition_id"] == "idle_run":
			machine.transitions[index]["duration"] = 0.25
	var evaluator := StateEvaluatorScript.new()
	var configured := evaluator.configure(machine, {"attack": 0.5})
	evaluator.set_parameter("speed", 1.0)
	var running := evaluator.update(0.1)
	evaluator.trigger("attack")
	var attacking := evaluator.update(0.1)
	var graph := RuleGraphScript.new("combat", "Combat")
	var rule_added := graph.add_rule("attack_sound", [{"type": "state", "value": "attack"}], [{"type": "trigger_event", "target": "swing"}, {"type": "set_variable", "target": "combo", "value": 1}], 10)
	var evaluation := graph.evaluate({"state": "attack"})
	var applied := graph.apply_actions({}, evaluation.get("actions", []))
	if configured and running.get("state_id") == "run" and attacking.get("state_id") == "attack" and rule_added and evaluation.get("actions", []).size() == 2 and applied.get("variables", {}).get("combo") == 1:
		print("  PASS: State conditions, triggers, cross-fades, and ordered rule actions evaluate")
		return 1
	printerr("  FAIL: State machine or rule graph evaluation failed")
	return 0


func test_state_machine_speed_scale() -> int:
	var machine := StateMachineScript.new("speed_test", "Speed Test")
	machine.add_state("idle", "idle")
	machine.add_state("done", "done")
	machine.set_state_property("idle", "loop", false)
	machine.set_state_property("idle", "speed_scale", 2.0)
	machine.add_transition("finished", "idle", "done", [{"type": "animation_complete"}])
	var evaluator := StateEvaluatorScript.new()
	var configured := evaluator.configure(machine, {"idle": 1.0})
	var halfway := evaluator.update(0.25)
	var completed := evaluator.update(0.3)
	if configured and is_equal_approx(float(halfway.get("state_time", 0.0)), 0.5) and str(completed.get("state_id", "")) == "done":
		print("  PASS: State speed scaling advances clip time and animation-complete transitions consistently")
		return 1
	printerr("  FAIL: State speed scale was ignored or completion did not transition")
	return 0


func test_baked_and_runtime_exports() -> int:
	var root := "user://milestone_12_14_exports"
	var red := _image(Color.RED)
	var blue := _image(Color.BLUE)
	var frames := [{"id": "red", "image": red}, {"id": "blue", "image": blue}]
	var atlas := AtlasPackerScript.new().pack(frames, Vector2i(32, 16), 1, 1)
	var atlas_images := AtlasPackerScript.new().render_pages(atlas)
	var spritesheet := SpritesheetExporterScript.new().export_frames(frames, root.path_join("atlas"), {"padding": 1, "manifest_format": "json"})
	var sequence := ImageSequenceExporterScript.new().export_frames(frames, root.path_join("sequence"), "png", 12.0)
	var gif := GifExporterScript.new().export_frames(frames, root.path_join("walk.gif"), 12.0)
	var video_exporter := VideoExporterScript.new()
	var mp4 := video_exporter.export_sequence(root.path_join("sequence/%04d.png"), root.path_join("walk.mp4"), 12.0) if video_exporter.is_available() else {"success": false}
	var webm := video_exporter.export_sequence(root.path_join("sequence/%04d.png"), root.path_join("walk.webm"), 12.0) if video_exporter.is_available() else {"success": false}
	var package := RuntimePackageScript.create({"project_id": "hero", "facing_grid": _grid_data(), "state_machine": _machine_data()}, {"name": "Hero"})
	var package_result := RuntimeExporterScript.new().export_project(package.get("content", {}), root.path_join("hero.chrpack"), package.get("metadata", {}))
	var native := GodotExporterScript.new().export_package(package, root.path_join("godot"), "hero")
	var gif_file := FileAccess.open(root.path_join("walk.gif"), FileAccess.READ)
	var gif_magic := gif_file.get_buffer(6).get_string_from_ascii() if gif_file != null else ""
	if gif_file != null:
		gif_file.close()
	if atlas.get("success", false) and atlas_images.size() == 1 and spritesheet.get("success", false) and sequence.get("success", false) and gif.get("success", false) and gif_magic == "GIF89a" and mp4.get("success", false) and webm.get("success", false) and package_result.get("success", false) and native.get("success", false):
		print("  PASS: Atlas, image, GIF, MP4, WebM, runtime package, .tres, and .tscn exports are written")
		return 1
	printerr("  FAIL: Export pipeline did not produce a valid artifact (ffmpeg=%s, mp4=%s, webm=%s, webm_log=%s)" % [video_exporter.is_available(), mp4.get("exit_code", "not-run"), webm.get("exit_code", "not-run"), str(webm.get("log", "")).right(800)])
	return 0


func test_importer_and_runtime_player() -> int:
	var root := "user://milestone_12_14_exports"
	var importer := ChrprojImporterScript.new()
	var imported := importer.import_data({"project_id": "hero", "facing_grid": _grid_data(), "state_machine": _machine_data()}, root.path_join("imported.tres"))
	var player := CharacterPlayerScript.new()
	add_child(player)
	var loaded := player.load_package(RuntimePackageScript.create({"facing_grid": _grid_data(), "state_machine": _machine_data()}))
	var facing := player.set_facing_direction(Vector2.UP)
	var rig_ready: bool = player.rebuild_skeleton(_rig_data())
	var ik_solved: bool = player.solve_two_bone_ik("root", "mid", Vector2(20.0, 20.0))
	player.equip("main_hand", {"item_id": "sword"})
	var equipped: bool = str((player.equipment.get("main_hand", {}) as Dictionary).get("item_id", "")) == "sword"
	player.free()
	if imported.get("success", false) and loaded and facing.get("primary_direction") == "north" and rig_ready and ik_solved and equipped:
		print("  PASS: .chrproj data imports into a native resource with playback, IK, and equipment swaps")
		return 1
	printerr("  FAIL: Runtime importer or CharacterPlayer2D behavior failed")
	return 0


func test_portable_addon_importer() -> int:
	var importer := PortableChrprojImporterScript.new()
	var result := importer.import_data({"project_id": "portable_hero", "facing_grid": _grid_data()}, "user://portable_addon_imported.tres")
	var resource := load("user://portable_addon_imported.tres") as Resource
	var script_path := str(resource.get_script().resource_path) if resource != null else ""
	if result.get("success", false) and resource != null and script_path.begins_with("res://addons/modular_character_runtime/"):
		print("  PASS: Self-contained addon importer writes a portable runtime resource")
		return 1
	printerr("  FAIL: Portable addon importer did not produce a consumer resource")
	return 0


func _image(colour: Color) -> Image:
	var image := Image.create_empty(4, 4, false, Image.FORMAT_RGBA8)
	image.fill(colour)
	return image


func _grid_data() -> Dictionary:
	var grid := FacingGridScript.new("hero_grid", "Hero")
	grid.set_direction_set(FacingGridScript.DirectionSet.EIGHT_WAY)
	for direction_id in grid.get_direction_ids():
		grid.set_cell(direction_id, {"asset_id": direction_id})
	return grid.to_dict()


func _machine_data() -> Dictionary:
	var machine := StateMachineScript.new("player", "Player")
	machine.add_state("idle", "idle")
	return machine.to_dict()


func _rig_data() -> Dictionary:
	return {"bones": {
		"root": {"name": "root", "parent_id": "", "local_position": [0.0, 0.0]},
		"mid": {"name": "mid", "parent_id": "root", "local_position": [20.0, 0.0]},
		"tip": {"name": "tip", "parent_id": "mid", "local_position": [20.0, 0.0]},
	}}
