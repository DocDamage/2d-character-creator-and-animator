# Packaged UI acceptance — exercises the exported application's real startup and shell.
extends Node

const STARTUP_SCENE := preload("res://app/bootstrap/startup.tscn")
const MAIN_SCENE := preload("res://app/shared_ui/main_window.tscn")
const StartupScript := preload("res://app/bootstrap/startup.gd")
const ProjectFactoryScript := preload("res://character/authoring/character_project_factory.gd")
const RESULT_PATH := "user://packaged_ui_acceptance_result.json"

var _passed := 0
var _failed := 0


func _ready() -> void:
	print("PACKAGED UI ACCEPTANCE: START")
	ThemeService.set_appearance_mode(ThemeService.AppearanceMode.OBSIDIAN)
	ThemeService.set_dpi_scale(1.0)
	get_tree().create_timer(30.0).timeout.connect(_on_watchdog_timeout)
	get_window().mode = Window.MODE_WINDOWED
	get_window().size = Vector2i(1440, 960)
	await get_tree().process_frame
	print("PACKAGED UI ACCEPTANCE: bundled sample")
	await _test_bundled_sample()
	print("PACKAGED UI ACCEPTANCE: startup flow")
	await _test_startup_flow()
	print("PACKAGED UI ACCEPTANCE: workspace shell")
	await _test_workspace_shell()
	ThemeService.set_appearance_mode(ThemeService.AppearanceMode.OBSIDIAN)
	print("PACKAGED UI ACCEPTANCE: %d PASS, %d FAIL" % [_passed, _failed])
	_write_result(0 if _failed == 0 else 1)
	get_tree().quit(0 if _failed == 0 else 1)


func _on_watchdog_timeout() -> void:
	_failed += 1
	printerr("  FAIL: Acceptance run exceeded 30 seconds")
	printerr("PACKAGED UI ACCEPTANCE: %d PASS, %d FAIL" % [_passed, _failed])
	_write_result(2)
	get_tree().quit(2)


func _test_bundled_sample() -> void:
	_check(FileAccess.file_exists(StartupScript.SAMPLE_PROJECT_PATH), "Bundled starter sample exists")
	var data: Dictionary = SerializationService.load_project(StartupScript.SAMPLE_PROJECT_PATH)
	_check(not data.is_empty(), "Bundled starter sample loads and validates")


func _test_startup_flow() -> void:
	AppState.set_meta("open_new_project_dialog", true)
	var startup := STARTUP_SCENE.instantiate()
	startup.transition_to_workspace = false
	add_child(startup)
	await get_tree().process_frame
	_check(startup.is_startup_complete(), "Packaged startup diagnostics complete")
	_check(startup.get_startup_errors().is_empty(), "Packaged startup has no diagnostic errors")
	var open_dialog := startup.get_node_or_null("OpenProjectDialog") as FileDialog
	var new_project_dialog := startup.get_node_or_null("NewProjectDialog") as Window
	var open_button := startup.get_node_or_null("MarginContainer/MainLayout/ContentSplit/QuickStartPanel/VBox/BtnOpenProject") as Button
	var sample_button := startup.get_node_or_null("MarginContainer/MainLayout/ContentSplit/QuickStartPanel/VBox/BtnOpenSample") as Button
	var route_capture := {"path": ""}
	startup.workspace_transition_requested.connect(func(path: String): route_capture["path"] = path)
	var startup_layout := startup.get_node_or_null("MarginContainer/MainLayout") as Control
	var appearance_picker := startup.get_node_or_null("MarginContainer/MainLayout/Header/HeaderRight/AppearanceOption") as OptionButton
	var startup_actions_connected := appearance_picker != null and not appearance_picker.item_selected.get_connections().is_empty()
	for button_path in ["MarginContainer/MainLayout/ContentSplit/QuickStartPanel/VBox/BtnNewProject", "MarginContainer/MainLayout/ContentSplit/QuickStartPanel/VBox/BtnOpenProject", "MarginContainer/MainLayout/ContentSplit/QuickStartPanel/VBox/BtnOpenSample", "MarginContainer/MainLayout/ContentSplit/QuickStartPanel/VBox/BtnContinueLast", "MarginContainer/MainLayout/Header/HeaderRight/BtnToggleLog", "MarginContainer/MainLayout/ContentSplit/RecentPanel/HeaderBar/BtnClearMissing"]:
		var action_button := startup.get_node_or_null(button_path) as Button
		startup_actions_connected = startup_actions_connected and action_button != null and not action_button.pressed.get_connections().is_empty()
	_check(startup_layout != null and _viewport_contains(startup_layout), "Startup layout stays inside the visible viewport")
	_check(startup_actions_connected, "Every visible startup action has a live handler")
	_check(new_project_dialog != null and new_project_dialog.visible, "Project Hub create route opens the new-project form")
	if new_project_dialog != null:
		new_project_dialog.hide()
	_check(appearance_picker != null and appearance_picker.item_count == 4 and appearance_picker.get_selected_id() == ThemeService.AppearanceMode.OBSIDIAN, "Startup exposes Obsidian Studio as the active appearance")
	_check(open_dialog != null and open_dialog.filters.size() >= 2, "Open Project dialog filters project formats")
	if open_button != null:
		open_button.pressed.emit()
	_check(open_dialog != null and open_dialog.visible, "Open Project button opens the file picker")
	if open_dialog != null:
		open_dialog.hide()
	if sample_button != null:
		sample_button.pressed.emit()
	await get_tree().process_frame
	_check(AppState.get_project_path() == StartupScript.SAMPLE_PROJECT_PATH, "Starter sample opens into application state")
	_check(String(route_capture["path"]) == StartupScript.SAMPLE_PROJECT_PATH, "Starter sample routes to the editor workspace")
	startup.queue_free()
	await get_tree().process_frame


func _test_workspace_shell() -> void:
	var authoring_path := "user://packaged_character_authoring.chrproj"
	var source_path := "user://packaged_character_layer.png"
	var created: bool = SerializationService.save_project(ProjectFactoryScript.create_manifest("Packaged Hero", "blank"), authoring_path)
	var source_image := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	source_image.fill(Color(0.0, 0.0, 0.0, 0.0))
	source_image.fill_rect(Rect2i(3, 3, 10, 10), Color(0.95, 0.45, 0.2, 1.0))
	var image_saved: bool = source_image.save_png(source_path) == OK
	_check(created and image_saved, "Packaged runtime creates a valid empty character project and source layer")
	AppState.open_project(authoring_path)
	var main_window := MAIN_SCENE.instantiate()
	add_child(main_window)
	await get_tree().process_frame
	await get_tree().process_frame
	var layout_manager: Node = main_window.get_dock_layout_manager()
	_check(layout_manager != null and layout_manager.get_registered_panels().size() == 17, "Shell registers all 17 dock panels")
	var diagnostics_before: bool = layout_manager.call("is_panel_visible", "panel_diagnostics")
	main_window.call("_toggle_diagnostics_drawer")
	var diagnostics_changed: bool = layout_manager.call("is_panel_visible", "panel_diagnostics") != diagnostics_before
	main_window.call("_toggle_diagnostics_drawer")
	_check(diagnostics_changed, "Diagnostics command changes the real dock-tab visibility")
	var shell_layout := main_window.get_node_or_null("RootVBox") as Control
	_check(shell_layout != null and _viewport_contains(shell_layout), "Workspace shell stays inside the visible viewport")
	var center_dock := main_window.get_node_or_null("RootVBox/MainHSplit/CenterVSplit/InnerHSplit/CenterDockRegion") as Control
	var project_panel := layout_manager.get_panel("panel_project_hub") as Control
	var project_hub := project_panel.get_node_or_null("MainVBox/ContentContainer/ProjectHubPanel") as Control if project_panel != null else null
	var project_state := project_hub.get_node_or_null("Margin/Root/Header/ProjectState") as Control if project_hub != null else null
	var compact_header := project_panel.get_node_or_null("MainVBox/HeaderBar") as Control if project_panel != null else null
	var compact_title := project_panel.get_node_or_null("MainVBox/HeaderBar/TitleLabel") as Label if project_panel != null else null
	var collapse_button := project_panel.get_node_or_null("MainVBox/HeaderBar/CollapseButton") as Button if project_panel != null else null
	_check(center_dock != null and project_panel != null and _control_contains(center_dock, project_panel), "Project hub dock stays inside the center region at 1440x960")
	_check(project_panel != null and project_hub != null and _control_contains(project_panel, project_hub), "Project hub content stays inside its dock at 1440x960")
	_check(project_hub != null and project_state != null and _control_contains(project_hub, project_state), "Project hub status stays visible at 1440x960")
	_check(compact_header != null and compact_header.visible and compact_header.custom_minimum_size.y <= 28.0 and compact_title != null and compact_title.text.is_empty() and collapse_button != null and collapse_button.visible, "Tabbed docks avoid duplicate headings without losing collapse controls")
	var creator_panel := layout_manager.get_panel("panel_character_creator") as Control
	var creator := creator_panel.get_node_or_null("MainVBox/ContentContainer/CharacterCreatorPanel") as Control if creator_panel != null else null
	var creator_preview := creator.get_node_or_null("Margin/Root/Content/PreviewCard/PreviewMargin/PreviewVBox/Preview") as Control if creator != null else null
	var preview_script_path: String = str(creator_preview.get_script().resource_path) if creator_preview != null and creator_preview.get_script() != null else ""
	_check(creator != null and creator.call("get_model") != null and creator.call("get_session") != null, "Character Creator binds itself to the opened packaged project")
	var creator_actions_connected := creator != null
	for button_path in ["Margin/Root/Header/Apply", "Margin/Root/Content/Picker/PickerMargin/PickerVBox/Import", "Margin/Root/Content/Picker/PickerMargin/PickerVBox/EditActions/Equip", "Margin/Root/Content/Picker/PickerMargin/PickerVBox/EditActions/Unequip", "Margin/Root/Content/Picker/PickerMargin/PickerVBox/History/Undo", "Margin/Root/Content/Picker/PickerMargin/PickerVBox/History/Redo", "Margin/Root/Content/PreviewCard/PreviewMargin/PreviewVBox/PreviewTools/ZoomOut", "Margin/Root/Content/PreviewCard/PreviewMargin/PreviewVBox/PreviewTools/Reset", "Margin/Root/Content/PreviewCard/PreviewMargin/PreviewVBox/PreviewTools/ZoomIn"]:
		var creator_button := creator.get_node_or_null(button_path) as Button if creator != null else null
		creator_actions_connected = creator_actions_connected and creator_button != null and not creator_button.pressed.get_connections().is_empty()
	var pixel_grid := creator.get_node_or_null("Margin/Root/Content/PreviewCard/PreviewMargin/PreviewVBox/PreviewTools/PixelGrid") as CheckButton if creator != null else null
	creator_actions_connected = creator_actions_connected and pixel_grid != null and not pixel_grid.toggled.get_connections().is_empty()
	_check(creator_actions_connected, "Every visible Character Creator action has a live handler")
	_check(preview_script_path == "res://character/authoring/character_layer_preview.gd" and creator.find_child("Randomize", true, false) == null, "Character Creator uses the real image compositor and exposes no generated-character action")
	var import_report: Dictionary = creator.call("import_part", source_path, "body") as Dictionary if creator != null else {}
	await get_tree().process_frame
	var copied_path := str(import_report.get("path", ""))
	_check(import_report.get("success", false) and int(creator.call("get_preview_loaded_layer_count")) == 1, "Imported image pixels appear in the packaged Character Creator preview")
	var asset_panel := layout_manager.get_panel("panel_assets") as Control
	var asset_browser := asset_panel.get_node_or_null("MainVBox/ContentContainer/AssetBrowser") as Control if asset_panel != null else null
	var asset_grid := asset_browser.get_node_or_null("VBox/Content/ItemGrid") as ItemList if asset_browser != null else null
	_check(asset_grid != null and asset_grid.item_count == 1, "Real Asset Browser reflects the imported character layer")
	var project_actions := main_window.get_node_or_null("ProjectPersistenceController")
	var autosave_report: Dictionary = project_actions.call("autosave_current") as Dictionary if project_actions != null else {}
	var autosave_path := str(autosave_report.get("path", ""))
	_check(autosave_report.get("success", false) and AppState.is_dirty() and FileAccess.file_exists(autosave_path), "Autosave writes a recovery snapshot without falsely clearing unsaved changes")
	WorkspaceManager.switch_workspace("character_creator")
	var undo_ok: bool = project_actions.call("undo_current") if project_actions != null else false
	var undo_cleared_preview := int(creator.call("get_preview_loaded_layer_count")) == 0
	var redo_ok: bool = project_actions.call("redo_current") if project_actions != null else false
	_check(undo_ok and undo_cleared_preview and redo_ok and int(creator.call("get_preview_loaded_layer_count")) == 1, "Global Undo and Redo route to the active Character Creator history")
	var save_button := project_hub.get_node_or_null("Margin/Root/Content/Center/Current/Margin/VBox/Buttons/SaveButton") as Button if project_hub != null else null
	if save_button != null: save_button.pressed.emit()
	await get_tree().process_frame
	var reloaded: Dictionary = SerializationService.load_project(authoring_path)
	var saved_parts: Dictionary = reloaded.get("metadata", {}).get("character_authoring", {}).get("parts", {})
	_check(save_button != null and not AppState.is_dirty() and saved_parts.size() == 1, "Project Hub Save writes and reloads the authored part instead of only clearing status")
	var save_as_path := "user://packaged_character_authoring_copy.chrproj"
	var save_as_report: Dictionary = project_actions.call("save_as_path", save_as_path) as Dictionary if project_actions != null else {}
	await get_tree().process_frame
	var copied_manifest: Dictionary = SerializationService.load_project(save_as_path)
	var copied_assets: Dictionary = copied_manifest.get("objects", {}).get("assets", {})
	var copied_asset_path := str((copied_assets.values()[0] as Dictionary).get("path", "")) if not copied_assets.is_empty() else ""
	_check(save_as_report.get("success", false) and AppState.get_project_path() == save_as_path and copied_asset_path != copied_path and FileAccess.file_exists(copied_asset_path), "Save As creates an editable project copy with independent artwork")
	AppState.close_project()
	await get_tree().process_frame
	_check(creator.call("get_session") == null and asset_grid != null and asset_grid.item_count == 0, "Closing a project releases the Character Creator session and clears stale assets")
	AppState.open_project(save_as_path)
	await get_tree().process_frame
	AppState.open_project(StartupScript.SAMPLE_PROJECT_PATH)
	await get_tree().process_frame
	AppState.mark_dirty()
	main_window.call("_on_close_project_choice", 0)
	var save_as_dialog := project_actions.get_node_or_null("SaveAsDialog") as FileDialog if project_actions != null else null
	_check(AppState.get_project_path() == StartupScript.SAMPLE_PROJECT_PATH and AppState.is_dirty(), "A failed read-only sample save cannot close the project or discard changes")
	if save_as_dialog != null: save_as_dialog.hide()
	AppState.clear_dirty()
	AppState.open_project(save_as_path)
	await get_tree().process_frame
	var primary_panels := {
		"project_assets": "panel_project_hub",
		"character_creator": "panel_character_creator",
		"rigging_deformation": "panel_viewport",
		"animation_studio": "panel_animation_composition",
		"weapon_equipment": "panel_weapon_wizard",
		"preview_export": "panel_batch_export",
	}
	var navigation_buttons := {
		"project_assets": "ProjectButton",
		"character_creator": "CreateButton",
		"rigging_deformation": "RigButton",
		"animation_studio": "AnimateButton",
		"weapon_equipment": "WeaponButton",
		"preview_export": "ExportButton",
	}
	for workspace_id in primary_panels:
		var switched: bool = WorkspaceManager.switch_workspace(workspace_id)
		await get_tree().process_frame
		_check(switched or WorkspaceManager.get_active_workspace_id() == workspace_id, "%s workspace switches" % workspace_id)
		var panel := layout_manager.get_panel(primary_panels[workspace_id]) as Control
		var panel_active := panel != null and panel.get_parent() is TabContainer and (panel.get_parent() as TabContainer).current_tab == panel.get_index()
		_check(panel_active, "%s primary panel activates" % workspace_id)
		var button_path := "RootVBox/TopHeaderBar/WorkspaceNavigation/" + String(navigation_buttons[workspace_id])
		var nav_button := main_window.get_node_or_null(button_path) as Button
		_check(nav_button != null and nav_button.button_pressed, "%s navigation tab reflects active state" % workspace_id)
	var command_button := main_window.get_node_or_null("RootVBox/TopHeaderBar/CommandPaletteButton") as Button
	var appearance_picker := main_window.get_node_or_null("RootVBox/TopHeaderBar/MoreButton") as OptionButton
	var brand_button := main_window.get_node_or_null("RootVBox/TopHeaderBar/BrandMark") as Button
	var help_button := main_window.get_node_or_null("RootVBox/TopHeaderBar/HelpButton") as Button
	var header_connected := command_button != null and not command_button.pressed.get_connections().is_empty() and appearance_picker != null and not appearance_picker.item_selected.get_connections().is_empty() and brand_button != null and not brand_button.pressed.get_connections().is_empty() and help_button != null and not help_button.pressed.get_connections().is_empty()
	for button_name in navigation_buttons.values():
		var workspace_button := main_window.get_node_or_null("RootVBox/TopHeaderBar/WorkspaceNavigation/" + str(button_name)) as Button
		header_connected = header_connected and workspace_button != null and not workspace_button.pressed.get_connections().is_empty()
	_check(header_connected, "Every visible redesigned header action has a live handler")
	if command_button != null:
		command_button.pressed.emit()
	await get_tree().process_frame
	var palette := main_window.get_node_or_null("CommandPalette") as Control
	_check(palette != null and palette.visible, "Command palette opens from the packaged shell")
	if palette != null and palette.has_method("close"):
		palette.close()
	var texture := main_window.get_node_or_null("RootTexture") as TextureRect
	_check(ThemeService.get_appearance_mode_name() == "Obsidian Studio" and texture != null and not texture.visible, "Obsidian Studio is the texture-free default UI")
	var classic_index := appearance_picker.get_item_index(ThemeService.AppearanceMode.PAPER_QUEST) if appearance_picker != null else -1
	if appearance_picker != null and classic_index >= 0:
		appearance_picker.select(classic_index)
		appearance_picker.item_selected.emit(classic_index)
	await get_tree().process_frame
	_check(ThemeService.get_appearance_mode_name() == "Paper Quest Classic" and texture != null and texture.visible, "Theme picker restores the original Paper Quest UI")
	ThemeService.set_appearance_mode(ThemeService.AppearanceMode.DARK_CRAFT)
	await get_tree().process_frame
	_check(ThemeService.get_appearance_mode_name() == "Dark Craft" and texture != null and texture.visible, "Original Dark Craft appearance remains available")
	ThemeService.set_high_contrast(true)
	await get_tree().process_frame
	_check(ThemeService.get_appearance_mode_name() == "High Contrast" and texture != null and not texture.visible, "High Contrast disables decorative texture")
	AppState.close_project()
	main_window.queue_free()
	await get_tree().process_frame
	for path in [source_path, copied_path, copied_asset_path, autosave_path, authoring_path, save_as_path]:
		if not str(path).is_empty(): DirAccess.remove_absolute(ProjectSettings.globalize_path(str(path)))


func _check(condition: bool, label: String) -> void:
	if condition:
		_passed += 1
		print("  PASS: " + label)
	else:
		_failed += 1
		printerr("  FAIL: " + label)


func _viewport_contains(control: Control) -> bool:
	var viewport_rect := control.get_viewport_rect()
	var control_rect := control.get_global_rect()
	return viewport_rect.encloses(control_rect)


func _control_contains(container: Control, child: Control) -> bool:
	return container.get_global_rect().encloses(child.get_global_rect())


func _write_result(exit_code: int) -> void:
	var file := FileAccess.open(RESULT_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify({
		"passed": _passed,
		"failed": _failed,
		"exit_code": exit_code,
		"completed_at": Time.get_datetime_string_from_system(true),
	}, "\t"))
	file.close()
