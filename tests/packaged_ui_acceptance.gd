# Packaged UI acceptance — exercises the exported application's real startup and shell.
extends Node

const STARTUP_SCENE := preload("res://app/bootstrap/startup.tscn")
const MAIN_SCENE := preload("res://app/shared_ui/main_window.tscn")
const StartupScript := preload("res://app/bootstrap/startup.gd")

var _passed := 0
var _failed := 0


func _ready() -> void:
	print("PACKAGED UI ACCEPTANCE: START")
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
	ThemeService.set_high_contrast(false)
	ThemeService.set_theme_mode(ThemeService.ThemeMode.LIGHT)
	print("PACKAGED UI ACCEPTANCE: %d PASS, %d FAIL" % [_passed, _failed])
	get_tree().quit(0 if _failed == 0 else 1)


func _on_watchdog_timeout() -> void:
	_failed += 1
	printerr("  FAIL: Acceptance run exceeded 30 seconds")
	printerr("PACKAGED UI ACCEPTANCE: %d PASS, %d FAIL" % [_passed, _failed])
	get_tree().quit(2)


func _test_bundled_sample() -> void:
	_check(FileAccess.file_exists(StartupScript.SAMPLE_PROJECT_PATH), "Bundled starter sample exists")
	var data: Dictionary = SerializationService.load_project(StartupScript.SAMPLE_PROJECT_PATH)
	_check(not data.is_empty(), "Bundled starter sample loads and validates")


func _test_startup_flow() -> void:
	var startup := STARTUP_SCENE.instantiate()
	startup.transition_to_workspace = false
	add_child(startup)
	await get_tree().process_frame
	_check(startup.is_startup_complete(), "Packaged startup diagnostics complete")
	_check(startup.get_startup_errors().is_empty(), "Packaged startup has no diagnostic errors")
	var open_dialog := startup.get_node_or_null("OpenProjectDialog") as FileDialog
	var open_button := startup.get_node_or_null("MarginContainer/MainLayout/ContentSplit/QuickStartPanel/VBox/BtnOpenProject") as Button
	var sample_button := startup.get_node_or_null("MarginContainer/MainLayout/ContentSplit/QuickStartPanel/VBox/BtnOpenSample") as Button
	var route_capture := {"path": ""}
	startup.workspace_transition_requested.connect(func(path: String): route_capture["path"] = path)
	var startup_layout := startup.get_node_or_null("MarginContainer/MainLayout") as Control
	_check(startup_layout != null and _viewport_contains(startup_layout), "Startup layout stays inside the visible viewport")
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
	var main_window := MAIN_SCENE.instantiate()
	add_child(main_window)
	await get_tree().process_frame
	await get_tree().process_frame
	var layout_manager: Node = main_window.get_dock_layout_manager()
	_check(layout_manager != null and layout_manager.get_registered_panels().size() == 16, "Shell registers all 16 dock panels")
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
	if command_button != null:
		command_button.pressed.emit()
	await get_tree().process_frame
	var palette := main_window.get_node_or_null("CommandPalette") as Control
	_check(palette != null and palette.visible, "Command palette opens from the packaged shell")
	if palette != null and palette.has_method("close"):
		palette.close()
	ThemeService.set_theme_mode(ThemeService.ThemeMode.DARK)
	await get_tree().process_frame
	_check(ThemeService.get_appearance_mode_name() == "Dark Craft", "Dark Craft appearance applies")
	ThemeService.set_high_contrast(true)
	await get_tree().process_frame
	var texture := main_window.get_node_or_null("RootTexture") as TextureRect
	_check(ThemeService.get_appearance_mode_name() == "High Contrast" and texture != null and not texture.visible, "High Contrast disables decorative texture")
	main_window.queue_free()
	await get_tree().process_frame


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
