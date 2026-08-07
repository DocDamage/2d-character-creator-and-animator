# Captures a production UI scene for local visual-regression inspection.
extends Node

var _scene_path := "res://app/bootstrap/startup.tscn"
var _output_path := "res://docs/implementation/evidence/PQ-UI/screenshots/paper-quest-ui.png"
var _project_path := ""
var _workspace_id := ""
var _appearance_id := ""
var _window_size := Vector2i(1440, 960)

func _ready() -> void:
	_parse_arguments()
	get_window().mode = Window.MODE_WINDOWED
	get_window().size = _window_size
	if ThemeService != null and not _appearance_id.is_empty():
		ThemeService.import_settings({"appearance_id": _appearance_id, "high_contrast": _appearance_id == "high_contrast"})
	if AppState != null and not _project_path.is_empty():
		AppState.open_project(_project_path)
	var packed := load(_scene_path) as PackedScene
	if packed == null:
		printerr("Could not load UI scene: " + _scene_path)
		get_tree().quit(1)
		return
	var captured_scene := packed.instantiate()
	add_child(captured_scene)
	await get_tree().process_frame
	if WorkspaceManager != null and not _workspace_id.is_empty():
		WorkspaceManager.switch_workspace(_workspace_id)
	await get_tree().process_frame
	await get_tree().process_frame
	var image := get_viewport().get_texture().get_image()
	var absolute_path := ProjectSettings.globalize_path(_output_path)
	DirAccess.make_dir_recursive_absolute(absolute_path.get_base_dir())
	var result := image.save_png(absolute_path)
	if result != OK:
		printerr("Could not save UI capture: " + absolute_path)
		get_tree().quit(1)
		return
	print("Saved UI capture: " + absolute_path)
	get_tree().quit()

func _parse_arguments() -> void:
	var args := OS.get_cmdline_user_args()
	for index in range(args.size()):
		if args[index] == "--scene" and index + 1 < args.size():
			_scene_path = args[index + 1]
		elif args[index] == "--output" and index + 1 < args.size():
			_output_path = args[index + 1]
		elif args[index] == "--project" and index + 1 < args.size():
			_project_path = args[index + 1]
		elif args[index] == "--workspace" and index + 1 < args.size():
			_workspace_id = args[index + 1]
		elif args[index] == "--appearance" and index + 1 < args.size():
			_appearance_id = args[index + 1]
		elif args[index] == "--size" and index + 1 < args.size():
			var dimensions := str(args[index + 1]).to_lower().split("x", false)
			if dimensions.size() == 2:
				var width := int(dimensions[0])
				var height := int(dimensions[1])
				if width >= 320 and height >= 240:
					_window_size = Vector2i(width, height)
