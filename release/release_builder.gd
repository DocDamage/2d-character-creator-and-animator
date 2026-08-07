# ReleaseBuilder -- Reproducible Windows export, portable bundle, and optional signing helpers.
class_name ReleaseBuilder
extends RefCounted

const ReadinessScript = preload("res://release/release_readiness.gd")

const PORTABLE_PRESET := "Windows Desktop"
const SINGLE_FILE_PRESET := "Windows Single File"
const INSTALLER_TEMPLATE := "release/windows/PaperQuestCharacterStudio.nsi"


func preflight() -> Dictionary:
	var readiness: Dictionary = ReadinessScript.new().validate()
	var preset_ok := FileAccess.file_exists("res://export_presets.cfg")
	var preset_text := FileAccess.get_file_as_string("res://export_presets.cfg") if preset_ok else ""
	var preset_metadata_ok := "application/icon=\"res://app/icon.svg\"" in preset_text and "application/modify_resources=true" in preset_text and "binary_format/embed_pck=true" in preset_text
	return {
		"ready": readiness.get("valid", false) and preset_ok and preset_metadata_ok,
		"readiness": readiness,
		"export_preset_available": preset_ok,
		"windows_metadata_configured": preset_metadata_ok,
		"release_identity": get_release_identity(),
		"portable_preset": PORTABLE_PRESET,
		"single_file_preset": SINGLE_FILE_PRESET,
		"required_platform": "Windows Desktop",
	}


func get_release_identity() -> Dictionary:
	var config: Dictionary = (ReadinessScript.new().validate().get("release_config", {}) as Dictionary).duplicate(true)
	return {
		"version": str(ProjectSettings.get_setting("application/config/version", "0.0.0")),
		"channel": str(config.get("channel", "stable")),
		"product_name": str(config.get("product_name", ProjectSettings.get_setting("application/config/name", "Paper Quest Character Studio"))),
		"company_name": str(config.get("company_name", "Paper Quest Studio")),
		"public_release_requires_code_signing": bool(config.get("public_release_requires_code_signing", true)),
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
	var build := build_windows(executable_path, SINGLE_FILE_PRESET)
	if bool(build.get("success", false)):
		var verification := verify_windows_artifacts(executable_path, true)
		build["verification"] = verification
		build["success"] = bool(verification.get("success", false))
	return build


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


## Verifies the actual payload shape before it is published.  A portable build
## must carry a sidecar PCK; a single-file build may omit it because Godot
## embeds the package in the executable.
func verify_windows_artifacts(executable_path: String, embedded_pck: bool = false) -> Dictionary:
	if not _is_safe_release_path(executable_path):
		return {"success": false, "errors": ["use a project-relative release/ executable path"], "artifacts": {}}
	var artifacts := get_windows_artifact_paths(executable_path)
	var errors: Array = []
	var warnings: Array = []
	if not bool(artifacts.get("executable_exists", false)):
		errors.append("Windows executable is missing.")
	elif FileAccess.get_file_as_bytes(_absolute_release_path(executable_path)).size() == 0:
		errors.append("Windows executable is empty.")
	if not embedded_pck and not bool(artifacts.get("pck_exists", false)):
		errors.append("Portable Windows builds require the matching PCK beside the EXE.")
	if embedded_pck and bool(artifacts.get("pck_exists", false)):
		warnings.append("A sidecar PCK is present beside the embedded build. It is harmless but should not be distributed as a single-file package.")
	return {"success": errors.is_empty(), "errors": errors, "warnings": warnings, "artifacts": artifacts, "embedded_pck": embedded_pck}


func verify_portable_windows_zip(zip_path: String, executable_name: String, pck_name: String) -> Dictionary:
	if not _is_safe_release_path(zip_path):
		return {"success": false, "errors": ["use a project-relative release/ ZIP path"], "contents": []}
	var absolute := _absolute_release_path(zip_path)
	if not FileAccess.file_exists(absolute):
		return {"success": false, "errors": ["portable ZIP is missing"], "contents": []}
	var reader := ZIPReader.new()
	var error := reader.open(absolute)
	if error != OK:
		return {"success": false, "errors": ["portable ZIP could not be read: " + error_string(error)], "contents": []}
	var files: PackedStringArray = reader.get_files()
	reader.close()
	var required := [executable_name, pck_name, "README.txt", "VERSION.json", "SHA256SUMS.txt"]
	var missing: Array = []
	for item in required:
		if str(item) not in files: missing.append(item)
	return {"success": missing.is_empty(), "errors": ["portable ZIP is missing: " + ", ".join(missing)] if not missing.is_empty() else [], "contents": Array(files)}


## Compiles the checked-in NSIS installer template when the release machine has
## makensis available.  Code signing remains a separate deliberate release
## action, so this method never attempts to discover or use credentials.
func build_windows_installer(executable_path: String, makensis_path: String, output_path: String = "release/windows/PaperQuestCharacterStudio-setup.exe") -> Dictionary:
	var artifacts_check := verify_windows_artifacts(executable_path, false)
	if not bool(artifacts_check.get("success", false)):
		return {"success": false, "errors": artifacts_check.get("errors", []), "verification": artifacts_check}
	if not _is_safe_release_path(output_path):
		return {"success": false, "errors": ["installer output must use a project-relative release/ path"]}
	if makensis_path.strip_edges().is_empty() or not FileAccess.file_exists(makensis_path):
		return {"success": false, "errors": ["provide the absolute path to makensis.exe on the release machine"], "verification": artifacts_check}
	var template_absolute := _absolute_release_path(INSTALLER_TEMPLATE)
	if not FileAccess.file_exists(template_absolute):
		return {"success": false, "errors": ["the NSIS installer template is missing"], "verification": artifacts_check}
	var output_absolute := _absolute_release_path(output_path)
	if DirAccess.make_dir_recursive_absolute(output_absolute.get_base_dir()) != OK:
		return {"success": false, "errors": ["could not create installer output directory"]}
	var identity := get_release_identity()
	var artifact_data: Dictionary = artifacts_check.get("artifacts", {}) as Dictionary
	var arguments: Array = ["/DAPP_VERSION=" + str(identity.get("version", "0.0.0")), "/DAPP_EXE=" + str(artifact_data.get("executable", "")).get_file(), "/DAPP_PCK=" + str(artifact_data.get("pck", "")).get_file(), "/DOUTPUT_EXE=" + output_absolute, template_absolute]
	var output: Array = []
	var code := OS.execute(makensis_path, arguments, output, true, false)
	return {"success": code == 0 and FileAccess.file_exists(output_absolute), "errors": [] if code == 0 else ["NSIS could not create the installer."], "exit_code": code, "output": "\n".join(output), "path": output_path, "verification": artifacts_check}


func write_update_manifest(output_path: String, download_url: String, notes: String, channel: String = "stable") -> Dictionary:
	if not _is_safe_release_path(output_path):
		return {"success": false, "errors": ["update manifests must use a project-relative release/ path"]}
	var url := download_url.strip_edges()
	if not url.is_empty() and not url.begins_with("https://"):
		return {"success": false, "errors": ["public update downloads must use HTTPS"]}
	var manifest := get_release_identity()
	manifest["download_url"] = url
	manifest["notes"] = notes.strip_edges()
	manifest["channel"] = channel.strip_edges() if not channel.strip_edges().is_empty() else "stable"
	manifest["published_at"] = Time.get_unix_time_from_system()
	var absolute := _absolute_release_path(output_path)
	if DirAccess.make_dir_recursive_absolute(absolute.get_base_dir()) != OK:
		return {"success": false, "errors": ["could not create the update-manifest folder"]}
	var file := FileAccess.open(absolute, FileAccess.WRITE)
	if file == null: return {"success": false, "errors": ["could not write update manifest"]}
	file.store_string(JSON.stringify(manifest, "\t"))
	file.close()
	return {"success": true, "errors": [], "path": output_path, "manifest": manifest}


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
	var version_error := _add_bytes_to_zip(zip, "VERSION.json", JSON.stringify(get_release_identity(), "\t").to_utf8_buffer()) if readme_error == OK else readme_error
	var checksum_error := _add_bytes_to_zip(zip, "SHA256SUMS.txt", _checksum_manifest(paths).to_utf8_buffer()) if version_error == OK else version_error
	zip.close()
	if checksum_error != OK:
		return {"success": false, "errors": ["could not add portable bundle metadata: " + error_string(checksum_error)]}
	var artifact_verification := verify_windows_artifacts(executable_path, false)
	var zip_verification := verify_portable_windows_zip(zip_path, executable_path.get_file(), str(artifacts.get("pck", "")).get_file())
	return {"success": FileAccess.file_exists(zip_absolute) and bool(artifact_verification.get("success", false)) and bool(zip_verification.get("success", false)), "path": zip_path, "absolute_path": zip_absolute, "artifacts": artifacts, "contents": [executable_path.get_file(), str(artifacts.get("pck", "")).get_file(), "README.txt", "VERSION.json", "SHA256SUMS.txt"], "verification": artifact_verification, "zip_verification": zip_verification}


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
	return "Paper Quest Character Studio portable build\n\nRun %s from this folder. Keep the matching .pck file beside the EXE; it contains the project data. Verify the downloaded files against SHA256SUMS.txt before sharing an external build.\n\nFor a single-file distribution, export the Windows Single File preset instead.\n" % executable_path.get_file()


func _checksum_manifest(paths: Array) -> String:
	var lines: Array[String] = []
	for raw_path in paths:
		var path := str(raw_path)
		var bytes := FileAccess.get_file_as_bytes(_absolute_release_path(path))
		var context := HashingContext.new()
		context.start(HashingContext.HASH_SHA256)
		context.update(bytes)
		lines.append(context.finish().hex_encode() + "  " + path.get_file())
	return "\n".join(lines) + "\n"


func _is_safe_release_path(path: String) -> bool:
	var normalized := path.replace("\\", "/").simplify_path()
	return not normalized.is_empty() and normalized.begins_with("release/") and not normalized.contains("../")


func _absolute_release_path(path: String) -> String:
	return ProjectSettings.globalize_path("res://" + path.replace("\\", "/"))
