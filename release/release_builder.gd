# ReleaseBuilder -- Reproducible Windows export, portable bundle, and optional signing helpers.
class_name ReleaseBuilder
extends RefCounted

const ReadinessScript = preload("res://release/release_readiness.gd")

const PORTABLE_PRESET := "Windows Desktop"
const SINGLE_FILE_PRESET := "Windows Single File"


func preflight() -> Dictionary:
	var readiness: Dictionary = ReadinessScript.new().validate()
	var preset_ok := FileAccess.file_exists("res://export_presets.cfg")
	return {
		"ready": readiness.get("valid", false) and preset_ok,
		"readiness": readiness,
		"export_preset_available": preset_ok,
		"portable_preset": PORTABLE_PRESET,
		"single_file_preset": SINGLE_FILE_PRESET,
		"required_platform": "Windows Desktop",
	}


func build_windows(output_path: String, preset_name: String = PORTABLE_PRESET) -> Dictionary:
	var check := preflight()
	if not check.get("ready", false):
		return {"success": false, "errors": ["release preflight failed"], "preflight": check}
	if not _is_safe_release_path(output_path):
		return {"success": false, "errors": ["use a project-relative release/ Windows output path"]}
	var output_directory := output_path.get_base_dir()
	var absolute_directory := ProjectSettings.globalize_path("res://" + output_directory)
	if DirAccess.make_dir_recursive_absolute(absolute_directory) != OK:
		return {"success": false, "errors": ["could not create Windows output directory"]}
	var absolute_output := ProjectSettings.globalize_path("res://" + output_path)
	var output: Array = []
	var code := OS.execute(OS.get_executable_path(), ["--headless", "--path", ProjectSettings.globalize_path("res://"), "--export-release", preset_name, absolute_output], output, true, false)
	return {"success": code == 0 and FileAccess.file_exists(absolute_output), "exit_code": code, "output": "\n".join(output), "path": output_path, "absolute_path": absolute_output, "preset": preset_name}


func build_portable_windows(executable_path: String = "release/windows/PaperQuestCharacterStudio.exe", zip_path: String = "release/windows/PaperQuestCharacterStudio-portable.zip") -> Dictionary:
	var build := build_windows(executable_path, PORTABLE_PRESET)
	if not build.get("success", false):
		return build
	var bundle := create_portable_windows_zip(executable_path, zip_path)
	bundle["build"] = build
	return bundle


func build_single_file_windows(executable_path: String = "release/windows/PaperQuestCharacterStudio.exe") -> Dictionary:
	return build_windows(executable_path, SINGLE_FILE_PRESET)


func get_windows_artifact_paths(executable_path: String) -> Dictionary:
	if executable_path.strip_edges().is_empty():
		return {"executable": "", "pck": "", "executable_exists": false, "pck_exists": false}
	var pck_path := executable_path.get_basename() + ".pck"
	return {
		"executable": executable_path,
		"pck": pck_path,
		"executable_exists": FileAccess.file_exists(_absolute_release_path(executable_path)),
		"pck_exists": FileAccess.file_exists(_absolute_release_path(pck_path)),
	}


func create_portable_windows_zip(executable_path: String, zip_path: String) -> Dictionary:
	if not _is_safe_release_path(executable_path) or not _is_safe_release_path(zip_path):
		return {"success": false, "errors": ["portable artifacts must use project-relative release/ paths"]}
	var artifacts := get_windows_artifact_paths(executable_path)
	if not artifacts.get("executable_exists", false) or not artifacts.get("pck_exists", false):
		return {"success": false, "errors": ["portable ZIP requires both the EXE and matching PCK"], "artifacts": artifacts}
	var zip_absolute := _absolute_release_path(zip_path)
	if DirAccess.make_dir_recursive_absolute(zip_absolute.get_base_dir()) != OK:
		return {"success": false, "errors": ["could not create portable ZIP directory"]}
	var zip := ZIPPacker.new()
	var open_error := zip.open(zip_absolute)
	if open_error != OK:
		return {"success": false, "errors": ["could not create portable ZIP: " + error_string(open_error)]}
	var paths := [str(artifacts.get("executable", "")), str(artifacts.get("pck", ""))]
	for path in paths:
		var add_error := _add_file_to_zip(zip, path, path.get_file())
		if add_error != OK:
			zip.close()
			return {"success": false, "errors": ["could not add " + path.get_file() + " to portable ZIP: " + error_string(add_error)]}
	var readme_error := _add_bytes_to_zip(zip, "README.txt", _portable_readme(executable_path).to_utf8_buffer())
	zip.close()
	if readme_error != OK:
		return {"success": false, "errors": ["could not add portable README: " + error_string(readme_error)]}
	return {"success": FileAccess.file_exists(zip_absolute), "path": zip_path, "absolute_path": zip_absolute, "artifacts": artifacts, "contents": [executable_path.get_file(), str(artifacts.get("pck", "")).get_file(), "README.txt"]}


func sign_windows_executable(executable_path: String, signtool_path: String, certificate_selector: String = "", timestamp_url: String = "") -> Dictionary:
	if not _is_safe_release_path(executable_path) or not FileAccess.file_exists(_absolute_release_path(executable_path)):
		return {"success": false, "errors": ["build the Windows executable before signing it"]}
	if signtool_path.strip_edges().is_empty() or not FileAccess.file_exists(signtool_path):
		return {"success": false, "errors": ["provide the absolute path to signtool.exe on the release machine"]}
	var arguments: Array = ["sign", "/fd", "SHA256"]
	var selector := certificate_selector.strip_edges()
	if selector.begins_with("file:"):
		arguments.append("/f")
		arguments.append(selector.trim_prefix("file:").strip_edges())
	elif not selector.is_empty():
		arguments.append("/n")
		arguments.append(selector)
	if not timestamp_url.strip_edges().is_empty():
		arguments.append("/tr")
		arguments.append(timestamp_url.strip_edges())
		arguments.append("/td")
		arguments.append("SHA256")
	arguments.append(_absolute_release_path(executable_path))
	var output: Array = []
	var code := OS.execute(signtool_path, arguments, output, true, false)
	return {"success": code == 0, "exit_code": code, "output": "\n".join(output), "path": executable_path, "signed": code == 0}


func _add_file_to_zip(zip: ZIPPacker, source_path: String, archive_path: String) -> Error:
	var file := FileAccess.open(_absolute_release_path(source_path), FileAccess.READ)
	if file == null:
		return ERR_FILE_NOT_FOUND
	var start_error := zip.start_file(archive_path)
	if start_error != OK:
		file.close()
		return start_error
	var write_error := zip.write_file(file.get_buffer(file.get_length()))
	file.close()
	return write_error


func _add_bytes_to_zip(zip: ZIPPacker, archive_path: String, bytes: PackedByteArray) -> Error:
	var start_error := zip.start_file(archive_path)
	if start_error != OK:
		return start_error
	return zip.write_file(bytes)


func _portable_readme(executable_path: String) -> String:
	return "Paper Quest Character Studio portable build\n\nRun %s from this folder. Keep the matching .pck file beside the EXE; it contains the project data.\n\nFor a single-file distribution, export the Windows Single File preset instead.\n" % executable_path.get_file()


func _is_safe_release_path(path: String) -> bool:
	var normalized := path.replace("\\", "/").simplify_path()
	return not normalized.is_empty() and normalized.begins_with("release/") and not normalized.contains("../")


func _absolute_release_path(path: String) -> String:
	return ProjectSettings.globalize_path("res://" + path.replace("\\", "/"))
