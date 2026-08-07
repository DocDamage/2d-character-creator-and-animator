# Studio CLI -- Headless production automation for imports, validation, reviews, and runtime delivery.
extends Node

const SessionScript = preload("res://character/authoring/character_project_session.gd")
const ContractBuilderScript = preload("res://runtime_plugin/preview/runtime_contract_builder.gd")
const RuntimeExporterScript = preload("res://export/engines/engine_runtime_package_exporter.gd")
const RuntimeQaScript = preload("res://quality/gameplay/runtime_qa_suite.gd")
const ReviewExporterScript = preload("res://export/review/review_package_exporter.gd")
const WatchServiceScript = preload("res://pipeline/watch_folder_service.gd")
const TemplateServiceScript = preload("res://pipeline/project_template_service.gd")
const AssetPackServiceScript = preload("res://pipeline/asset_pack_service.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var parsed := _parse(OS.get_cmdline_user_args())
	var command := str(parsed.get("command", "")).to_lower()
	var report: Dictionary = {}
	match command:
		"validate": report = _validate(parsed)
		"runtime-export": report = _runtime_export(parsed)
		"review-export": report = _review_export(parsed)
		"bulk-import": report = _bulk_import(parsed)
		"watch-scan": report = _watch_scan(parsed, false)
		"watch-apply": report = _watch_scan(parsed, true)
		"template-create": report = _template_create(parsed)
		"asset-pack-export": report = _asset_pack_export(parsed)
		"asset-pack-import": report = _asset_pack_import(parsed)
		"help", "": report = {"success": command == "help", "usage": _usage()}
		_: report = {"success": false, "errors": ["Unknown command: " + command], "usage": _usage()}
	print(JSON.stringify(report, "\t", true, false))
	get_tree().quit(0 if bool(report.get("success", false)) else 1)


func _validate(options: Dictionary) -> Dictionary:
	var manifest := _load_project(options)
	if manifest.is_empty(): return _missing_project()
	var contract := ContractBuilderScript.build(manifest)
	var validation := ContractBuilderScript.validate(contract)
	var qa := RuntimeQaScript.new().run(contract, {"output_directory": str(options.get("output", ""))})
	return {"success": bool(validation.get("valid", false)) and bool(qa.get("success", false)), "validation": validation, "qa": qa}


func _runtime_export(options: Dictionary) -> Dictionary:
	var manifest := _load_project(options)
	if manifest.is_empty(): return _missing_project()
	var output := str(options.get("output", "")).strip_edges()
	if output.is_empty(): return {"success": false, "errors": ["--output is required for runtime-export."]}
	var targets := str(options.get("targets", "godot,unity,unreal")).split(",", false)
	var production: Dictionary = manifest.get("metadata", {}).get("production_suite", {}) as Dictionary
	return RuntimeExporterScript.new().export_all(manifest, production, output, targets)


func _review_export(options: Dictionary) -> Dictionary:
	var session = _open_session(str(options.get("project", "")))
	if session == null: return _missing_project()
	var output := str(options.get("output", ""))
	var report := ReviewExporterScript.new().export_package(session, output, {"warnings_confirmed": true})
	session.queue_free()
	return report


func _bulk_import(options: Dictionary) -> Dictionary:
	var project := str(options.get("project", ""))
	var source := str(options.get("source", ""))
	if source.is_empty() or not DirAccess.dir_exists_absolute(_absolute(source)): return {"success": false, "errors": ["--source must be an existing artwork folder."]}
	var session = _open_session(project)
	if session == null: return _missing_project()
	var files: Array = []
	_collect_images(source, files)
	var mapping: Dictionary = session.map_files_to_slots(files)
	var imported: Array = []
	var errors: Array = []
	for raw_mapping in mapping.get("mapped", []) as Array:
		var item: Dictionary = raw_mapping as Dictionary
		var result: Dictionary = session.import_part(str(item.get("path", "")), str(item.get("slot_id", "")))
		if bool(result.get("success", false)): imported.append(result)
		else: errors.append_array(result.get("errors", []))
	var saved: Dictionary = session.save_project() if errors.is_empty() else {"success": false}
	session.queue_free()
	return {"success": errors.is_empty() and bool(saved.get("success", false)), "mapped": mapping.get("mapped", []), "unmatched": mapping.get("unmatched", []), "imported": imported.size(), "errors": errors if not errors.is_empty() else saved.get("errors", [])}


func _watch_scan(options: Dictionary, apply: bool) -> Dictionary:
	var manifest := _load_project(options)
	if manifest.is_empty(): return _missing_project()
	var entries: Array = manifest.get("metadata", {}).get("production_suite", {}).get("pipeline", {}).get("watch_folders", []) as Array
	var watcher = WatchServiceScript.new()
	watcher.configure(entries)
	if not apply: return {"success": true, "scan": watcher.scan_once()}
	var session = _open_session(str(options.get("project", "")))
	if session == null: return _missing_project()
	var report := watcher.apply_approved(session)
	if (report.get("applied", []) as Array).size() > 0:
		var production: Dictionary = session.get_production_suite_data() as Dictionary
		production["pipeline"]["watch_folders"] = watcher.to_dict()
		session.set_production_suite_data(production, "Applied Approved Watch-Folder Reimports")
		session.save_project()
	session.queue_free()
	return report


func _template_create(options: Dictionary) -> Dictionary:
	var output := str(options.get("output", ""))
	if output.is_empty(): return {"success": false, "errors": ["--output is required for template-create."]}
	return TemplateServiceScript.write(str(options.get("template", "blank")), str(options.get("name", "Untitled Project")), output)


func _asset_pack_export(options: Dictionary) -> Dictionary:
	var manifest := _load_project(options)
	if manifest.is_empty(): return _missing_project()
	var output := str(options.get("output", ""))
	if output.is_empty(): return {"success": false, "errors": ["--output is required for asset-pack-export."]}
	return AssetPackServiceScript.new().export_pack(manifest, output)


func _asset_pack_import(options: Dictionary) -> Dictionary:
	var source := str(options.get("source", "")); var output := str(options.get("output", ""))
	if source.is_empty() or output.is_empty(): return {"success": false, "errors": ["--source and --output are required for asset-pack-import."]}
	return AssetPackServiceScript.new().extract_pack(source, output)


func _load_project(options: Dictionary) -> Dictionary:
	var path := str(options.get("project", ""))
	if path.is_empty() or not FileAccess.file_exists(_absolute(path)): return {}
	var file := FileAccess.open(_absolute(path), FileAccess.READ)
	if file == null: return {}
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	return parsed as Dictionary if parsed is Dictionary else {}


func _open_session(path: String):
	if path.is_empty(): return null
	var session = SessionScript.new()
	get_tree().root.add_child(session)
	var opened: Dictionary = session.open_project(path)
	if not bool(opened.get("success", false)):
		session.queue_free()
		return null
	return session


func _parse(arguments: PackedStringArray) -> Dictionary:
	var result: Dictionary = {}
	var index := 0
	while index < arguments.size():
		var argument := arguments[index]
		if argument.begins_with("--"):
			var split := argument.trim_prefix("--").split("=", true, 1)
			var key := split[0].replace("-", "_")
			if split.size() > 1: result[key] = split[1]
			elif index + 1 < arguments.size() and not arguments[index + 1].begins_with("--"):
				result[key] = arguments[index + 1]; index += 1
			else: result[key] = true
		elif not result.has("command"):
			result["command"] = argument
		index += 1
	return result


func _collect_images(folder: String, output: Array) -> void:
	var directory := DirAccess.open(_absolute(folder))
	if directory == null: return
	directory.list_dir_begin()
	var entry := directory.get_next()
	while not entry.is_empty():
		if entry != "." and entry != "..":
			var path := folder.path_join(entry)
			if directory.current_is_dir(): _collect_images(path, output)
			elif path.get_extension().to_lower() in ["png", "webp", "jpg", "jpeg", "bmp", "tga"]: output.append(path)
		entry = directory.get_next()
	directory.list_dir_end()


func _missing_project() -> Dictionary: return {"success": false, "errors": ["--project must identify a readable .chrproj file."]}
func _absolute(path: String) -> String: return ProjectSettings.globalize_path(path) if path.begins_with("res://") or path.begins_with("user://") else path
func _usage() -> Array:
	return ["validate --project <project.chrproj> [--output <folder>]", "runtime-export --project <project.chrproj> --output <folder> [--targets godot,unity,unreal]", "review-export --project <project.chrproj> [--output <folder>]", "bulk-import --project <project.chrproj> --source <art-folder>", "watch-scan|watch-apply --project <project.chrproj>", "template-create --template <blank|combat_2d|dialogue|pixel_fighter> --name <name> --output <project.chrproj>", "asset-pack-export --project <project.chrproj> --output <pack.assetpack>", "asset-pack-import --source <pack.assetpack> --output <folder>"]
