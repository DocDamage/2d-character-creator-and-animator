# Captures a production UI scene for local visual-regression inspection.
extends Node

var _scene_path := "res://app/bootstrap/startup.tscn"
var _output_path := "res://docs/implementation/evidence/PQ-UI/screenshots/paper-quest-ui.png"
var _project_path := ""
var _workspace_id := ""
var _appearance_id := ""
var _window_size := Vector2i(1440, 960)
const CAPTURE_SCENE := "res://tools/capture_ui.tscn"

func _ready() -> void:
	_parse_arguments()
	if _requires_windowed_capture():
		_run_windowed_capture()
		return
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
	var texture := get_viewport().get_texture()
	if texture == null:
		_fail_capture("The active renderer did not provide a viewport texture.")
		return
	var image := texture.get_image()
	if image == null or image.is_empty():
		_fail_capture("The active renderer returned an empty viewport image.")
		return
	var absolute_path := ProjectSettings.globalize_path(_output_path)
	DirAccess.make_dir_recursive_absolute(absolute_path.get_base_dir())
	var result := image.save_png(absolute_path)
	if result != OK:
		printerr("Could not save UI capture: " + absolute_path)
		get_tree().quit(1)
		return
	print("Saved UI capture: " + absolute_path)
	get_tree().quit()


func _requires_windowed_capture() -> bool:
	return OS.has_feature("headless") or DisplayServer.get_name().to_lower().contains("headless")


func _run_windowed_capture() -> void:
	var output: Array = []
	var arguments := PackedStringArray([
		"--path", ProjectSettings.globalize_path("res://"),
		"--scene", CAPTURE_SCENE,
		"--",
	])
	# Rebuild only this tool's parsed arguments instead of forwarding the host
	# process arguments. On Windows, forwarding can retain --headless on the
	# child even when it is filtered from the visible user-argument list.
	arguments.append_array(PackedStringArray(["--scene", _scene_path, "--output", _output_path]))
	if not _project_path.is_empty(): arguments.append_array(PackedStringArray(["--project", _project_path]))
	if not _workspace_id.is_empty(): arguments.append_array(PackedStringArray(["--workspace", _workspace_id]))
	if not _appearance_id.is_empty(): arguments.append_array(PackedStringArray(["--appearance", _appearance_id]))
	arguments.append_array(PackedStringArray(["--size", "%dx%d" % [_window_size.x, _window_size.y]]))
	var exit_code := OS.execute(OS.get_executable_path(), arguments, output, true)
	for line in output:
		print(str(line))
	get_tree().quit(exit_code)


func _fail_capture(reason: String) -> void:
	printerr("Could not capture UI: " + reason)
	get_tree().quit(1)

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
