# Unit test suite for Recent Projects service, Startup screen, and NewProjectDialog
# Validates REQ-APP-009 requirements under engine runtime.
extends Node

const RecentProjectsServiceScript = preload("res://app/bootstrap/recent_projects_service.gd")
const NewProjectDialogScript = preload("res://app/bootstrap/new_project_dialog.gd")
const StartupScript = preload("res://app/bootstrap/startup.gd")
const ProjectFactoryScript = preload("res://character/authoring/character_project_factory.gd")
const AssetRegistryScript = preload("res://core/assets/asset_registry.gd")
const ImageImporterScript = preload("res://core/assets/image_importer.gd")
const STARTUP_SCENE_PATH := "res://app/bootstrap/startup.tscn"
const TEST_PROJ_PATH_1 := "user://test_project_1.json"
const TEST_PROJ_PATH_2 := "user://test_project_2.json"
const NON_EXISTENT_PATH := "user://non_existent_project_999.json"

var _service: Node = null

func _get_service() -> Node:
	if RecentProjectsService != null:
		return RecentProjectsService
	if _service == null:
		_service = RecentProjectsServiceScript.new()
		add_child(_service)
	return _service


func run_tests() -> Dictionary:
	var results := {"passed": 0, "failed": 0, "errors": []}

	print("[TEST 13] Recent Projects Service & Startup Screen Workflows...")

	_test_recent_service_basic(results)
	_test_recent_service_persistence(results)
	_test_recent_service_missing_handling(results)
	_test_startup_scene_integration(results)
	_test_packaged_sample_and_open_dialog(results)
	_test_search_filtering(results)
	_test_new_project_dialog(results)
	_test_quick_start_actions(results)
	_test_project_management_actions(results)

	if _service != null and _service != RecentProjectsService:
		_service.queue_free()
		_service = null

	return results


func _test_recent_service_basic(results: Dictionary) -> void:
	var srv := _get_service()
	srv.call("clear_all")
	var list: Array = srv.call("get_recent_projects")
	if list.is_empty():
		print("  PASS: RecentProjectsService initializes cleanly when cleared.")
		results["passed"] += 1
	else:
		results["failed"] += 1
		results["errors"].append("RecentProjectsService not empty after clear_all.")

	srv.call("add_project", TEST_PROJ_PATH_1, "Test Project 1")
	list = srv.call("get_recent_projects")
	if list.size() == 1 and list[0]["title"] == "Test Project 1":
		print("  PASS: Project added to RecentProjectsService successfully.")
		results["passed"] += 1
	else:
		results["failed"] += 1
		results["errors"].append("Failed to add project to RecentProjectsService.")

	srv.call("add_project", TEST_PROJ_PATH_2, "Test Project 2")
	srv.call("add_project", TEST_PROJ_PATH_1, "Test Project 1")
	list = srv.call("get_recent_projects")
	if list.size() == 2 and list[0]["path"] == TEST_PROJ_PATH_1:
		print("  PASS: RecentProjectsService deduplicates and moves item to front.")
		results["passed"] += 1
	else:
		results["failed"] += 1
		results["errors"].append("RecentProjectsService deduplication failed.")


func _test_recent_service_persistence(results: Dictionary) -> void:
	var srv := _get_service()
	var exported: Dictionary = srv.call("export_settings")
	if exported.has("recent_projects"):
		print("  PASS: RecentProjectsService exports settings dictionary successfully.")
		results["passed"] += 1
	else:
		results["failed"] += 1
		results["errors"].append("export_settings failed.")

	srv.call("clear_all")
	var success: bool = srv.call("import_settings", exported)
	var list: Array = srv.call("get_recent_projects")
	if success and list.size() == 2:
		print("  PASS: RecentProjectsService imported settings dictionary successfully.")
		results["passed"] += 1
	else:
		results["failed"] += 1
		results["errors"].append("import_settings failed to restore projects.")


func _test_recent_service_missing_handling(results: Dictionary) -> void:
	var srv := _get_service()
	srv.call("add_project", NON_EXISTENT_PATH, "Non Existent")
	var list: Array = srv.call("get_recent_projects")
	var found_missing := false
	for item in list:
		if item["path"] == NON_EXISTENT_PATH and not item["exists"]:
			found_missing = true
			break

	if found_missing:
		print("  PASS: Missing project correctly identified with exists=false.")
		results["passed"] += 1
	else:
		results["failed"] += 1
		results["errors"].append("Failed to detect missing project status.")

	srv.call("clear_missing")
	list = srv.call("get_recent_projects")
	var has_non_existent := false
	for item in list:
		if item["path"] == NON_EXISTENT_PATH:
			has_non_existent = true

	if not has_non_existent:
		print("  PASS: clear_missing() pruned invalid paths successfully.")
		results["passed"] += 1
	else:
		results["failed"] += 1
		results["errors"].append("clear_missing() failed to remove missing entries.")


func _test_startup_scene_integration(results: Dictionary) -> void:
	var startup_packed := ResourceLoader.load(STARTUP_SCENE_PATH) as PackedScene
	if startup_packed == null:
		results["failed"] += 1
		results["errors"].append("Failed to load startup scene.")
		return

	var startup_node := startup_packed.instantiate()
	add_child(startup_node)

	if startup_node.is_startup_complete():
		print("  PASS: Startup screen instantiated and completed diagnostic sequence.")
		results["passed"] += 1
	else:
		results["failed"] += 1
		results["errors"].append("Startup diagnostic sequence failed.")

	var item_list: ItemList = startup_node.get_node_or_null("MarginContainer/MainLayout/ContentSplit/RecentPanel/RecentList")
	if item_list != null:
		print("  PASS: Startup screen contains RecentList UI component.")
		results["passed"] += 1
	else:
		results["failed"] += 1
		results["errors"].append("RecentList UI component missing.")

	startup_node.queue_free()


func _test_search_filtering(results: Dictionary) -> void:
	var srv := _get_service()
	srv.call("clear_all")
	srv.call("add_project", "user://alpha_hero.json", "Alpha Hero")
	srv.call("add_project", "user://beta_villain.json", "Beta Villain")

	var startup_packed := ResourceLoader.load(STARTUP_SCENE_PATH) as PackedScene
	var startup_node := startup_packed.instantiate()
	add_child(startup_node)

	var search_edit: LineEdit = startup_node.get_node_or_null("MarginContainer/MainLayout/ContentSplit/RecentPanel/SearchBar/SearchEdit")
	var item_list: ItemList = startup_node.get_node_or_null("MarginContainer/MainLayout/ContentSplit/RecentPanel/RecentList")

	if search_edit != null and item_list != null:
		search_edit.text = "Alpha"
		search_edit.text_changed.emit("Alpha")
		if item_list.item_count == 1 and item_list.get_item_text(0).contains("Alpha"):
			print("  PASS: Search filter correctly filtered recent list to matching items.")
			results["passed"] += 1
		else:
			results["failed"] += 1
			results["errors"].append("Search filter did not match expected count (got %d)." % item_list.item_count)
	else:
		results["failed"] += 1
		results["errors"].append("Search Edit or Item List missing for filter test.")

	startup_node.queue_free()


func _test_packaged_sample_and_open_dialog(results: Dictionary) -> void:
	var startup_packed := ResourceLoader.load(STARTUP_SCENE_PATH) as PackedScene
	var startup_node := startup_packed.instantiate()
	startup_node.transition_to_workspace = false
	add_child(startup_node)
	var sample_path: String = StartupScript.SAMPLE_PROJECT_PATH
	var dialog := startup_node.get_node_or_null("OpenProjectDialog") as FileDialog
	var open_button := startup_node.get_node_or_null("MarginContainer/MainLayout/ContentSplit/QuickStartPanel/VBox/BtnOpenProject") as Button
	if FileAccess.file_exists(sample_path) and sample_path.begins_with("res://samples/"):
		print("  PASS: Quick Start points to a bundled production sample.")
		results["passed"] += 1
	else:
		results["failed"] += 1
		results["errors"].append("Quick Start sample is missing or not production packaged: " + sample_path)
	if dialog != null and open_button != null and dialog.filters.size() >= 2:
		open_button.pressed.emit()
		if dialog.visible:
			print("  PASS: Open Project launches a filtered file picker instead of the sample shortcut.")
			results["passed"] += 1
		else:
			results["failed"] += 1
			results["errors"].append("Open Project file picker did not become visible.")
	else:
		results["failed"] += 1
		results["errors"].append("Open Project file picker or filters are missing.")
	if dialog != null:
		dialog.hide()
	startup_node.queue_free()


func _test_new_project_dialog(results: Dictionary) -> void:
	var dlg_node = NewProjectDialogScript.new()
	add_child(dlg_node)

	var res_box := {"emitted": false, "path": ""}

	dlg_node.connect("project_created", func(path, _title, _tmpl):
		res_box["emitted"] = true
		res_box["path"] = path
	)

	dlg_node.call("_on_confirmed")
	if res_box["emitted"] and not String(res_box["path"]).is_empty():
		print("  PASS: NewProjectDialog emitted project_created signal on confirmation.")
		results["passed"] += 1
	else:
		results["failed"] += 1
		results["errors"].append("NewProjectDialog confirmation signal failed (emitted=%s, path='%s')." % [str(res_box["emitted"]), str(res_box["path"])])

	dlg_node.queue_free()


func _test_quick_start_actions(results: Dictionary) -> void:
	var startup_packed := ResourceLoader.load(STARTUP_SCENE_PATH) as PackedScene
	var startup_node := startup_packed.instantiate()
	startup_node.transition_to_workspace = false
	add_child(startup_node)

	var res_box := {"emitted": false, "transition": ""}
	startup_node.connect("project_created", func(_p, _t):
		res_box["emitted"] = true
	)
	startup_node.connect("workspace_transition_requested", func(path): res_box["transition"] = path)

	var created_path := "user://test_new_created.chrproj"
	if FileAccess.file_exists(created_path): DirAccess.remove_absolute(ProjectSettings.globalize_path(created_path))
	startup_node.create_new_project(created_path, "Test New Created", "blank")
	var is_loaded: bool = AppState.is_project_loaded()
	var created_data: Dictionary = SerializationService.load_project(created_path)
	var authoring: Dictionary = created_data.get("metadata", {}).get("character_authoring", {})
	var overwrite_blocked := not ProjectFactoryScript.save_new_project(created_path, "Overwrite Attempt", "blank")
	if res_box["emitted"] and is_loaded and res_box["transition"] == created_path and not created_data.is_empty() and (authoring.get("slots", {}) as Dictionary).size() == 8 and overwrite_blocked:
		print("  PASS: create_new_project writes a valid editable manifest and refuses to overwrite an existing project.")
		results["passed"] += 1
	else:
		results["failed"] += 1
		results["errors"].append("create_new_project failed (emitted=%s, loaded=%s, transition=%s)." % [str(res_box["emitted"]), str(is_loaded), str(res_box["transition"])])

	startup_node.queue_free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(created_path))
	_get_service().call("clear_all")


func _test_project_management_actions(results: Dictionary) -> void:
	var srv := _get_service()
	srv.call("clear_all")
	var root := "user://recent_management_%d" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(root))
	var source_path := root.path_join("body.png")
	var project_path := root.path_join("hero.chrproj")
	var image := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.3, 0.6, 0.9, 1.0))
	var image_saved := image.save_png(source_path) == OK
	var manifest := ProjectFactoryScript.create_manifest("Recent Hero", "blank")
	var registry = AssetRegistryScript.new()
	var asset: Dictionary = ImageImporterScript.import_image(source_path, registry)
	registry.free()
	if not asset.is_empty():
		manifest.objects.assets[asset.get("asset_id", "")] = asset
	var project_saved := SerializationService.save_project(manifest, project_path)
	srv.call("add_project", project_path, "Recent Hero")
	var renamed: Dictionary = srv.call("rename_project", project_path, "Renamed Hero")
	var duplicated: Dictionary = srv.call("duplicate_project", project_path, "Copied Hero")
	var copied_path := str(duplicated.get("path", ""))
	var copied_manifest: Dictionary = SerializationService.load_project(copied_path)
	var copied_assets: Dictionary = copied_manifest.get("objects", {}).get("assets", {})
	var copied_asset_path := str((copied_assets.values()[0] as Dictionary).get("path", "")) if not copied_assets.is_empty() else ""
	var archived := bool(srv.call("archive_project", project_path))
	var active_recents: Array = srv.call("get_recent_projects")
	var missing_action: Dictionary = srv.call("get_actionable_error", root.path_join("missing.chrproj"))
	var archive_hidden := true
	for entry in active_recents:
		if str((entry as Dictionary).get("path", "")) == project_path:
			archive_hidden = false
	var management_ok: bool = image_saved and project_saved and renamed.get("success", false) and duplicated.get("success", false) and copied_path != project_path and FileAccess.file_exists(copied_path) and not copied_asset_path.is_empty() and copied_asset_path != source_path and FileAccess.file_exists(copied_asset_path) and archived and archive_hidden and str(missing_action.get("kind", "")) == "missing"
	if management_ok:
		print("  PASS: Recent project management renames, independently duplicates, archives, and explains missing projects.")
		results["passed"] += 1
	else:
		results["failed"] += 1
		results["errors"].append("Recent project management actions did not complete safely.")
	for path in [source_path, copied_asset_path, project_path, copied_path]:
		if not str(path).is_empty():
			DirAccess.remove_absolute(ProjectSettings.globalize_path(str(path)))
	srv.call("clear_all")
