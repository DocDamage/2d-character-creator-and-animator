extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var resource := load("res://generated/hero.tres") as Resource
	var scene := load("res://generated/hero.tscn") as PackedScene
	var editor_imported_resource := load("res://portable_input.chrproj") as Resource
	var editor_imported_package: Variant = editor_imported_resource.get("package_data") if editor_imported_resource != null else null
	if resource == null or scene == null or not editor_imported_package is Dictionary:
		_fail("generated resource, scene, or editor-imported .chrproj did not load")
		return
	var player := scene.instantiate()
	if not player.has_method("set_facing_direction") or not player.has_method("equip"):
		_fail("generated scene does not expose the runtime player API")
		return
	root.add_child(player)
	await process_frame
	var auto_loaded_state := str(player.call("get_current_state_id"))
	var loaded: bool = player.call("load_runtime_data", resource)
	var facing: Dictionary = player.call("set_facing_direction", Vector2.UP)
	var ik_solved: bool = player.call("solve_two_bone_ik", "root", "mid", Vector2(20, 20))
	var events: Array = []
	player.connect("animation_event", func(event: Dictionary): events.append(event))
	player.call("set_parameter", "speed", 1.0)
	player.call("_process", 0.1)
	player.call("_process", 0.1)
	var mesh: Variant = player.call("add_mesh", {"vertices": [{"position": [0.0, 0.0]}, {"position": [4.0, 0.0]}, {"position": [0.0, 4.0]}]})
	player.call("equip", "main_hand", {"item_id": "sword"})
	var equipment: Dictionary = player.get("equipment")
	var script_path := str(player.get_script().resource_path)
	var package: Variant = resource.get("package_data")
	var state_id := str(player.call("get_current_state_id"))
	var editor_imported_content: Dictionary = (editor_imported_package as Dictionary).get("content", {}) as Dictionary
	if auto_loaded_state != "idle" or not loaded or facing.get("primary_direction") != "north" or not ik_solved or state_id != "run" or events.size() < 2 or not mesh is Polygon2D or str((equipment.get("main_hand", {}) as Dictionary).get("item_id", "")) != "sword" or not package is Dictionary or str(editor_imported_content.get("project_id", "")) != "portable_editor_import" or not script_path.begins_with("res://addons/modular_character_runtime/"):
		_fail("portable runtime player or editor import did not load, face, solve, transition, emit, mesh, or equip correctly (auto_state=%s loaded=%s facing=%s ik=%s state=%s events=%s content_events=%s mesh=%s equipment=%s package=%s editor_import=%s script=%s)" % [auto_loaded_state, loaded, facing, ik_solved, state_id, events, player.get("_content").get("events", []), mesh, equipment, package is Dictionary, editor_imported_content, script_path])
		return
	print("CLEAN_CONSUMER_PASS")
	quit(0)


func _fail(message: String) -> void:
	printerr("CLEAN_CONSUMER_FAIL: " + message)
	quit(1)
