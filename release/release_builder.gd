# ReleaseBuilder -- Explicit preflight and optional Windows export invocation for a configured release machine.
class_name ReleaseBuilder
extends RefCounted

const ReadinessScript = preload("res://release/release_readiness.gd")


func preflight() -> Dictionary:
	var readiness: Dictionary = ReadinessScript.new().validate()
	var preset_ok := FileAccess.file_exists("res://export_presets.cfg")
	return {"ready": readiness.get("valid", false) and preset_ok, "readiness": readiness, "export_preset_available": preset_ok, "required_platform": "Windows Desktop"}


func build_windows(output_path: String, preset_name: String = "Windows Desktop") -> Dictionary:
	var check := preflight()
	if not check.get("ready", false): return {"success": false, "errors": ["release preflight failed"], "preflight": check}
	if output_path.strip_edges().is_empty() or output_path.contains("..") or not output_path.begins_with("release/"): return {"success": false, "errors": ["use a project-relative release/ Windows output path"]}
	var output_directory := output_path.get_base_dir()
	if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://").path_join(output_directory)) != OK:
		return {"success": false, "errors": ["could not create Windows output directory"]}
	var output: Array = []
	var code := OS.execute(OS.get_executable_path(), ["--headless", "--path", ProjectSettings.globalize_path("res://"), "--export-release", preset_name, output_path], output, true, false)
	return {"success": code == 0, "exit_code": code, "output": "\n".join(output), "path": output_path}
