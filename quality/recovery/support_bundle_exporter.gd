# SupportBundleExporter -- Creates an opt-in, local diagnostics handoff.
#
# Nothing is transmitted by this service.  The artist chooses whether to share
# the resulting ZIP, which contains no artwork and no raw project manifest by
# default.  It is intended for a support conversation after a crash or export
# problem.
class_name SupportBundleExporter
extends RefCounted


func create_bundle(session = null, output_root: String = "user://support_bundles") -> Dictionary:
	var root := output_root.strip_edges()
	if root.is_empty(): root = "user://support_bundles"
	if DirAccess.make_dir_recursive_absolute(_absolute(root)) != OK:
		return _failure("Could not create the support-bundle folder.")
	var name := "paper_quest_support_%d" % Time.get_unix_time_from_system()
	var folder := root.path_join(name)
	var suffix := 2
	while DirAccess.dir_exists_absolute(_absolute(folder)):
		folder = root.path_join(name + "_%d" % suffix)
		suffix += 1
	if DirAccess.make_dir_recursive_absolute(_absolute(folder)) != OK:
		return _failure("Could not create the support-bundle contents folder.")
	var environment := {
		"application": str(ProjectSettings.get_setting("application/config/name", "Paper Quest Character Studio")),
		"version": str(ProjectSettings.get_setting("application/config/version", "unknown")),
		"engine": Engine.get_version_info(),
		"os": OS.get_name(),
		"processor_count": OS.get_processor_count(),
		"created_at": Time.get_unix_time_from_system(),
	}
	var diagnostics: Array = DiagnosticsService.get_recent(200) if DiagnosticsService != null else []
	var summary := _project_summary(session)
	_write_json(folder.path_join("environment.json"), environment)
	_write_json(folder.path_join("diagnostics.json"), {"entries": diagnostics})
	_write_json(folder.path_join("project_summary.json"), summary)
	_write_text(folder.path_join("README.txt"), _readme(summary))
	var zip_path := root.path_join(folder.get_file() + ".zip")
	var zip_report := _zip_folder(folder, zip_path)
	if not bool(zip_report.get("success", false)):
		return {"success": false, "errors": zip_report.get("errors", []), "folder": folder}
	return {"success": true, "errors": [], "folder": folder, "zip": zip_path, "summary": summary, "contains_artwork": false, "uploaded": false}


func _project_summary(session) -> Dictionary:
	if session == null or not is_instance_valid(session) or session.model == null:
		return {"project_open": false}
	var readiness: Dictionary = session.get_readiness_report()
	var scale: Dictionary = session.get_project_scale_report()
	return {
		"project_open": true,
		"project_name": str(session.manifest.get("project_name", "Untitled Project")),
		"schema_version": str(session.manifest.get("schema_version", "unknown")),
		"read_only": bool(session.is_read_only()),
		"asset_count": session.asset_registry.list_assets().size(),
		"layer_count": session.get_layer_entries().size(),
		"clip_count": session.get_animation_clips().size(),
		"readiness": {"errors": (readiness.get("errors", []) as Array).size(), "warnings": (readiness.get("warnings", []) as Array).size()},
		"scale": scale.get("counts", {}),
	}


func _readme(summary: Dictionary) -> String:
	return "# Paper Quest support bundle\n\nThis ZIP was created locally at the artist's request. It is not uploaded automatically.\n\nIt contains application/environment information, recent diagnostics, and a redacted project summary. It does not contain imported artwork, audio, or the full project manifest.\n\nProject open: %s\n" % str(summary.get("project_open", false))


func _zip_folder(folder: String, zip_path: String) -> Dictionary:
	var zip := ZIPPacker.new()
	if zip.open(_absolute(zip_path)) != OK: return _failure("Could not create the support ZIP.")
	var files: Array = []
	_collect_files(folder, files)
	for path in files:
		var archive_path := str(path).trim_prefix(folder.trim_suffix("/") + "/")
		var file := FileAccess.open(_absolute(str(path)), FileAccess.READ)
		if file == null or zip.start_file(archive_path) != OK:
			if file != null: file.close()
			zip.close()
			return _failure("Could not add support-bundle file: " + archive_path)
		var error := zip.write_file(file.get_buffer(file.get_length()))
		file.close()
		if error != OK:
			zip.close()
			return _failure("Could not write support-bundle file: " + archive_path)
	zip.close()
	return {"success": FileAccess.file_exists(_absolute(zip_path)), "errors": [], "path": zip_path}


func _collect_files(folder: String, output: Array) -> void:
	var directory := DirAccess.open(_absolute(folder))
	if directory == null: return
	directory.list_dir_begin()
	var entry := directory.get_next()
	while not entry.is_empty():
		if entry != "." and entry != "..":
			var path := folder.path_join(entry)
			if directory.current_is_dir(): _collect_files(path, output)
			else: output.append(path)
		entry = directory.get_next()
	directory.list_dir_end()


func _write_json(path: String, data: Dictionary) -> bool:
	var file := FileAccess.open(_absolute(path), FileAccess.WRITE)
	if file == null: return false
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	return true


func _write_text(path: String, contents: String) -> bool:
	var file := FileAccess.open(_absolute(path), FileAccess.WRITE)
	if file == null: return false
	file.store_string(contents)
	file.close()
	return true


func _absolute(path: String) -> String:
	return ProjectSettings.globalize_path(path) if path.begins_with("res://") or path.begins_with("user://") else path


func _failure(message: String) -> Dictionary:
	return {"success": false, "errors": [message]}
