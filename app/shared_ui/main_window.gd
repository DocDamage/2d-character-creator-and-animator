class_name MainWindow
extends Control
signal workspace_changed(workspace_name: String)
signal layout_preset_changed(preset_name: String)
const DockPanelScript = preload("res://app/shared_ui/dock_panel.gd")
const DockLayoutManagerScript = preload("res://app/shared_ui/dock_layout_manager.gd")
const UnsavedDialogScript = preload("res://app/application_state/unsaved_changes_dialog.gd")
const DiagDrawerScene = preload("res://core/diagnostics/diagnostics_drawer.tscn")
const FacingDirectionSetEditorScene = preload("res://facing/facing_direction_set_editor.tscn")
const PoseLibraryPanelScene = preload("res://rigging/poses/pose_library_panel.tscn")
const RetargetPreviewPanelScene = preload("res://rigging/retargeting/retarget_preview_panel.tscn")
const WeaponAuthoringWizardScene = preload("res://weapons/authoring/weapon_authoring_wizard.tscn")
const CharacterCreatorPanelScene = preload("res://character/authoring/character_creator_panel.tscn")
const ProjectHubPanelScene = preload("res://app/bootstrap/project_hub_panel.tscn")
const MediaAuthoringPanelScene = preload("res://media/media_authoring_panel.tscn"); const AnimationCompositionPanelScene = preload("res://animation/authoring/animation_composition_panel.tscn"); const BatchExportPanelScene = preload("res://export/batch/batch_export_panel.tscn"); const QualityDashboardPanelScene = preload("res://quality/dashboard/quality_dashboard_panel.tscn"); const AssetBrowserScene = preload("res://app/workspaces/asset_browser.tscn")
const DocumentSelectionScript = preload("res://app/shared_ui/document_selection.gd")
const RigHierarchyEditorScript = preload("res://rigging/bones/rig_hierarchy_editor.gd")
const AuthoringCanvasViewportScript = preload("res://app/shared_ui/authoring_canvas_viewport.gd")
const AuthoringInspectorScript = preload("res://app/shared_ui/authoring_inspector.gd")
const AnimationTimelineEditorScript = preload("res://animation/timeline/animation_timeline_editor.gd")
const AnimationPreviewControllerScript = preload("res://animation/preview/animation_preview_controller.gd")
const ReviewPackagePanelScript = preload("res://export/review/review_package_panel.gd")
const RuntimeDeliveryPanelScript = preload("res://app/production/runtime_delivery_panel.gd")
const MotionLibraryPanelScript = preload("res://app/production/motion_library_panel.gd")
const PipelineCollaborationPanelScript = preload("res://app/production/pipeline_collaboration_panel.gd")
const PresentationPanelScript = preload("res://app/production/presentation_panel.gd")
@onready var dock_layout_manager: Node = $DockLayoutManager
@onready var status_message_label: Label = %StatusMessageLabel
@onready var status_info_label: Label = %StatusInfoLabel
@onready var menu_bar: MenuBar = %TopMenuBar
@onready var preset_option_button: OptionButton = %PresetOptionButton
@onready var workspace_option_button: OptionButton = get_node_or_null("%WorkspaceOptionButton") as OptionButton
@onready var command_palette_button: Button = get_node_or_null("%CommandPaletteButton") as Button
@onready var command_palette: Control = get_node_or_null("%CommandPalette") as Control
@onready var unsaved_changes_dialog: Control = get_node_or_null("%UnsavedChangesDialog") as Control
@onready var project_actions: Node = get_node_or_null("%ProjectPersistenceController")
@onready var top_header: HBoxContainer = $RootVBox/TopHeaderBar
@onready var left_dock_region: Control = %LeftDockRegion
@onready var right_dock_region: Control = %RightDockRegion
@onready var bottom_dock_region: Control = %BottomDockRegion
@onready var appearance_picker: OptionButton = $RootVBox/TopHeaderBar/MoreButton
@onready var help_button: Button = $RootVBox/TopHeaderBar/HelpButton
@onready var status_project_label: Label = %StatusProjectLabel
@onready var status_workspace_label: Label = %StatusWorkspaceLabel
var _current_status: String = "Ready"
var _responsive_state: Dictionary = {}
var document_selection: Node = null
var _authoring_session = null
var animation_preview_controller: Node = null
const MINIMUM_EDITOR_SIZE := Vector2i(1280, 720)


func _ready() -> void:
	_configure_window_constraints()
	if ThemeService != null: ThemeService.apply_to_window(get_window())
	_setup_document_selection()
	_setup_dock_regions()
	_setup_default_panels()
	_setup_document_editor_bindings()
	_setup_workspace_manager()
	_setup_menu_header()
	_setup_shortcut_commands()
	_setup_app_state_listeners()
	_setup_focus_framework()
	get_viewport().size_changed.connect(_apply_responsive_layout)
	if ThemeService != null and not ThemeService.dpi_scale_changed.is_connected(_on_dpi_scale_changed):
		ThemeService.dpi_scale_changed.connect(_on_dpi_scale_changed)
	call_deferred("_apply_responsive_layout")
	set_status_message("Ready. Application main window initialized.")
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_handle_close_request()
func get_dock_layout_manager() -> Node:
	if dock_layout_manager == null:
		dock_layout_manager = get_node_or_null("DockLayoutManager")
	return dock_layout_manager
func set_status_message(message: String) -> void:
	_current_status = message
	if status_message_label != null:
		var dirty_suffix := " [Unsaved Changes]" if AppState != null and AppState.is_dirty() else ""
		status_message_label.text = _current_status + dirty_suffix
	if DiagnosticsService != null:
		DiagnosticsService.info("MainWindow status: " + message, "MainWindow")
func get_status_message() -> String: return _current_status
func get_responsive_layout_state() -> Dictionary: return _responsive_state.duplicate(true)
func get_document_selection() -> Node: return document_selection

func _on_dpi_scale_changed(_scale: float) -> void:
	_apply_responsive_layout()


func _configure_window_constraints() -> void:
	var window := get_window()
	if window != null:
		window.min_size = MINIMUM_EDITOR_SIZE


func _apply_responsive_layout() -> void:
	var window := get_window()
	var available_size := Vector2(window.size) if window != null and window.size.x > 0 and window.size.y > 0 else get_viewport_rect().size
	apply_responsive_layout_for_size(available_size)


func apply_responsive_layout_for_size(viewport: Vector2, dpi_scale: float = -1.0) -> Dictionary:
	var scale := dpi_scale if dpi_scale > 0.0 else (ThemeService.get_dpi_scale() if ThemeService != null else 1.0)
	var width := viewport.x / maxf(1.0, scale)
	var height := viewport.y / maxf(1.0, scale)
	var mode := "wide"
	if width <= 1320.0 or height <= 760.0:
		mode = "compact"
		command_palette_button.visible = false
		help_button.visible = false
		appearance_picker.custom_minimum_size = Vector2(138, 40)
		left_dock_region.custom_minimum_size = Vector2(210, 0)
		right_dock_region.custom_minimum_size = Vector2(238, 0)
		bottom_dock_region.custom_minimum_size = Vector2(0, 164)
		status_workspace_label.visible = false
		status_info_label.visible = false
		top_header.custom_minimum_size.y = 58.0
	elif width <= 1510.0:
		mode = "medium"
		command_palette_button.visible = false
		help_button.visible = true
		appearance_picker.custom_minimum_size = Vector2(168, 40)
		left_dock_region.custom_minimum_size = Vector2(235, 0)
		right_dock_region.custom_minimum_size = Vector2(270, 0)
		bottom_dock_region.custom_minimum_size = Vector2(0, 190)
		status_workspace_label.visible = true
		status_info_label.visible = false
		top_header.custom_minimum_size.y = 64.0
	else:
		command_palette_button.visible = true
		help_button.visible = true
		appearance_picker.custom_minimum_size = Vector2(240, 40)
		left_dock_region.custom_minimum_size = Vector2(270, 0)
		right_dock_region.custom_minimum_size = Vector2(320, 0)
		bottom_dock_region.custom_minimum_size = Vector2(0, 220)
		status_workspace_label.visible = true
		status_info_label.visible = true
		top_header.custom_minimum_size.y = 72.0
	_responsive_state = {"mode": mode, "width": width, "height": height, "dpi_scale": scale, "command_palette_visible": command_palette_button.visible, "overflow_expected": mode != "wide", "left_min_width": left_dock_region.custom_minimum_size.x, "right_min_width": right_dock_region.custom_minimum_size.x, "header_height": top_header.custom_minimum_size.y}
	return get_responsive_layout_state()
func get_panel(panel_id: String) -> Control:
	var mgr := get_dock_layout_manager(); return mgr.call("get_panel", panel_id) as Control if mgr != null else null
func bind_pose_rig(rig: Dictionary) -> void:
	var panel := get_panel("panel_pose_library")
	var library_panel := panel.get_node_or_null("MainVBox/ContentContainer/PoseLibraryPanel") if panel != null else null
	if library_panel != null:
		library_panel.call("bind_rig", rig)
func bind_retarget_context(source_pose: Variant, target_profile: Variant, target_rig: Dictionary, bone_map: Dictionary, factors: Dictionary, correction_layer: Variant = null) -> void:
	var panel := get_panel("panel_retarget_preview")
	var preview_panel := panel.get_node_or_null("MainVBox/ContentContainer/RetargetPreviewPanel") if panel != null else null
	if preview_panel != null:
		preview_panel.call("bind_context", source_pose, target_profile, target_rig, bone_map, factors, correction_layer)
func bind_weapon_authoring_context(weapon: Variant, pose_profile: Variant, rig: Dictionary, hand_pose_library: Variant = null) -> void:
	var wizard := get_panel("panel_weapon_wizard").get_node_or_null("MainVBox/ContentContainer/WeaponAuthoringWizard") if get_panel("panel_weapon_wizard") != null else null
	if wizard != null:
		wizard.call("bind_context", weapon, pose_profile, rig, hand_pose_library)
func bind_character_creator_context(part_registry: Variant, slot_registry: Variant, body_types: Array, weapons: Array = [], character_id: String = "character", display_name: String = "Character", body_type_id: String = "") -> Dictionary:
	var creator := get_panel("panel_character_creator").get_node_or_null("MainVBox/ContentContainer/CharacterCreatorPanel") if get_panel("panel_character_creator") != null else null
	return creator.call("bind_context", part_registry, slot_registry, body_types, weapons, character_id, display_name, body_type_id) as Dictionary if creator != null else {}
func bind_media_authoring_context(audio_track: Variant, viseme_track: Variant, reference_library: Variant = null) -> void:
	var media := get_panel("panel_media_authoring").get_node_or_null("MainVBox/ContentContainer/MediaAuthoringPanel") if get_panel("panel_media_authoring") != null else null; if media != null: media.call("bind_context", audio_track, viseme_track, reference_library)
func bind_animation_composition_context(blend: Variant, state_model: Variant, rule_model: Variant) -> void:
	var composition := get_panel("panel_animation_composition").get_node_or_null("MainVBox/ContentContainer/AnimationCompositionPanel") if get_panel("panel_animation_composition") != null else null; if composition != null: composition.call("bind_context", blend, state_model, rule_model)
func bind_batch_export_context(controller: Variant = null) -> void: var batch := get_panel("panel_batch_export").get_node_or_null("MainVBox/ContentContainer/BatchExportPanel") if get_panel("panel_batch_export") != null else null; if batch != null: batch.call("bind_context", controller)
func bind_quality_project_path(path: String) -> void: var quality := get_panel("panel_quality_dashboard").get_node_or_null("MainVBox/ContentContainer/QualityDashboardPanel") if get_panel("panel_quality_dashboard") != null else null; if quality != null: quality.call("bind_project_path", path)
func select_workspace_preset(preset_name: String) -> void:
	var mgr := get_dock_layout_manager(); if mgr != null and mgr.call("apply_preset_by_name", preset_name):
		layout_preset_changed.emit(preset_name)
		set_status_message("Layout preset changed to: " + preset_name)
func open_command_palette() -> void: if command_palette != null: command_palette.call("open")
func close_command_palette() -> void: if command_palette != null: command_palette.call("close")
func toggle_command_palette() -> void: if command_palette != null: command_palette.call("toggle")
func _setup_dock_regions() -> void:
	var mgr := get_dock_layout_manager()
	if mgr == null: return
	mgr.call("register_dock_region", "LEFT", get_node_or_null("%LeftDockRegion") as Control)
	mgr.call("register_dock_region", "RIGHT", get_node_or_null("%RightDockRegion") as Control)
	mgr.call("register_dock_region", "BOTTOM", get_node_or_null("%BottomDockRegion") as Control)
	mgr.call("register_dock_region", "CENTER", get_node_or_null("%CenterDockRegion") as Control)
	mgr.call("register_split_container", get_node_or_null("%MainHSplit") as SplitContainer)
	mgr.call("register_split_container", get_node_or_null("%CenterVSplit") as SplitContainer)
	mgr.call("register_split_container", get_node_or_null("%InnerHSplit") as SplitContainer)
func _setup_document_selection() -> void:
	if document_selection != null: return
	document_selection = DocumentSelectionScript.new()
	document_selection.name = "DocumentSelection"
	add_child(document_selection)
	animation_preview_controller = AnimationPreviewControllerScript.new()
	animation_preview_controller.name = "AnimationPreviewController"
	add_child(animation_preview_controller)

func _setup_document_editor_bindings() -> void:
	var creator := _get_character_creator()
	if creator != null:
		if creator.has_signal("project_session_ready") and not creator.project_session_ready.is_connected(_on_project_session_ready):
			creator.project_session_ready.connect(_on_project_session_ready)
		if creator.has_signal("layer_selected") and not creator.layer_selected.is_connected(_on_creator_layer_selected):
			creator.layer_selected.connect(_on_creator_layer_selected)
		var existing_session = creator.call("get_session")
		if existing_session != null: _on_project_session_ready(existing_session)
	if AppState != null and not AppState.project_closed.is_connected(_on_authoring_project_closed):
		AppState.project_closed.connect(_on_authoring_project_closed)

func _get_character_creator() -> Control:
	var panel := get_panel("panel_character_creator")
	return panel.get_node_or_null("MainVBox/ContentContainer/CharacterCreatorPanel") as Control if panel != null else null

func _get_authoring_dock_content(panel_id: String, content_name: String) -> Control:
	var panel := get_panel(panel_id)
	return panel.get_node_or_null("MainVBox/ContentContainer/" + content_name) as Control if panel != null else null

func _on_project_session_ready(session) -> void:
	if _authoring_session != null and is_instance_valid(_authoring_session) and _authoring_session.session_changed.is_connected(_on_authoring_session_changed):
		_authoring_session.session_changed.disconnect(_on_authoring_session_changed)
	_authoring_session = session
	if _authoring_session != null and is_instance_valid(_authoring_session) and not _authoring_session.session_changed.is_connected(_on_authoring_session_changed):
		_authoring_session.session_changed.connect(_on_authoring_session_changed)
	if animation_preview_controller != null: animation_preview_controller.call("bind_session", _authoring_session)
	for info in [["panel_hierarchy", "RigHierarchyEditor"], ["panel_viewport", "AuthoringCanvasViewport"], ["panel_inspector", "AuthoringInspector"], ["panel_timeline", "AnimationTimelineEditor"]]:
		var editor := _get_authoring_dock_content(str(info[0]), str(info[1]))
		if editor != null:
			editor.call("bind_session", _authoring_session)
			if editor.has_method("bind_preview_controller"): editor.call("bind_preview_controller", animation_preview_controller)
	var timeline_editor := _get_authoring_dock_content("panel_timeline", "AnimationTimelineEditor")
	var viewport_editor := _get_authoring_dock_content("panel_viewport", "AuthoringCanvasViewport")
	var onion_receiver := Callable(viewport_editor, "set_onion_layers") if viewport_editor != null else Callable()
	if timeline_editor != null and viewport_editor != null and timeline_editor.has_signal("onion_frames_changed") and not timeline_editor.onion_frames_changed.is_connected(onion_receiver):
		timeline_editor.onion_frames_changed.connect(onion_receiver)
	var hub := _get_authoring_dock_content("panel_project_hub", "ProjectHubPanel")
	if hub != null:
		if hub.has_method("bind_session"): hub.call("bind_session", _authoring_session)
		if hub.has_method("bind_preview_controller"): hub.call("bind_preview_controller", animation_preview_controller)
	var review_panel := _get_authoring_dock_content("panel_review_package", "ReviewPackagePanel")
	if review_panel != null and review_panel.has_method("bind_session"): review_panel.call("bind_session", _authoring_session)
	for info in [["panel_runtime_delivery", "RuntimeDeliveryPanel"], ["panel_motion_library", "MotionLibraryPanel"], ["panel_pipeline_collaboration", "PipelineCollaborationPanel"], ["panel_presentation", "PresentationPanel"]]:
		var production_panel := _get_authoring_dock_content(str(info[0]), str(info[1]))
		if production_panel != null and production_panel.has_method("bind_session"): production_panel.call("bind_session", _authoring_session)
	if document_selection != null: document_selection.clear()
	if _authoring_session != null:
		bind_pose_rig(_authoring_session.get_active_rig())
		bind_quality_project_path(str(_authoring_session.project_path))
		call_deferred("_maybe_show_project_workflow")

func _on_authoring_session_changed(_description: String) -> void:
	if _authoring_session != null and is_instance_valid(_authoring_session):
		bind_pose_rig(_authoring_session.get_active_rig())

func _on_authoring_project_closed() -> void:
	if _authoring_session != null and is_instance_valid(_authoring_session) and _authoring_session.session_changed.is_connected(_on_authoring_session_changed):
		_authoring_session.session_changed.disconnect(_on_authoring_session_changed)
	_authoring_session = null
	if animation_preview_controller != null: animation_preview_controller.call("bind_session", null)
	for info in [["panel_hierarchy", "RigHierarchyEditor"], ["panel_viewport", "AuthoringCanvasViewport"], ["panel_inspector", "AuthoringInspector"], ["panel_timeline", "AnimationTimelineEditor"]]:
		var editor := _get_authoring_dock_content(str(info[0]), str(info[1]))
		if editor != null: editor.call("bind_session", null)
	var hub := _get_authoring_dock_content("panel_project_hub", "ProjectHubPanel")
	if hub != null and hub.has_method("bind_session"): hub.call("bind_session", null)
	var review_panel := _get_authoring_dock_content("panel_review_package", "ReviewPackagePanel")
	if review_panel != null and review_panel.has_method("bind_session"): review_panel.call("bind_session", null)
	for info in [["panel_runtime_delivery", "RuntimeDeliveryPanel"], ["panel_motion_library", "MotionLibraryPanel"], ["panel_pipeline_collaboration", "PipelineCollaborationPanel"], ["panel_presentation", "PresentationPanel"]]:
		var production_panel := _get_authoring_dock_content(str(info[0]), str(info[1]))
		if production_panel != null and production_panel.has_method("bind_session"): production_panel.call("bind_session", null)
	if document_selection != null: document_selection.clear()


func _maybe_show_project_workflow() -> void:
	if _authoring_session == null or not is_instance_valid(_authoring_session): return
	# Automated/headless runs can still bind a newly created project. They do not
	# have a usable window position for a non-exclusive authoring dialog, while
	# the persisted workflow state remains fully testable through its service.
	var command_line: PackedStringArray = OS.get_cmdline_args()
	if OS.has_feature("headless") or "--headless" in command_line or DisplayServer.get_name().to_lower().contains("headless"): return
	var workflow: Dictionary = _authoring_session.get_workflow_state()
	if not bool(workflow.get("new_project", false)) or bool(workflow.get("completed", true)) or bool(workflow.get("deferred", false)): return
	var hub := _get_authoring_dock_content("panel_project_hub", "ProjectHubPanel")
	if hub != null and hub.has_method("open_guided_setup"): hub.call("open_guided_setup")

func _on_creator_layer_selected(part_id: String) -> void:
	if document_selection != null and not part_id.is_empty(): document_selection.call("select", "layer", part_id, {"source": "character_creator"})
func _setup_default_panels() -> void:
	var mgr := get_dock_layout_manager()
	if mgr == null: return
	var panels := [
		["panel_assets", "Asset Browser", DockPanelScript.DockRegion.LEFT, "LEFT"],
		["panel_hierarchy", "Hierarchy & Rig", DockPanelScript.DockRegion.LEFT, "LEFT"], ["panel_pose_library", "Saved Poses", DockPanelScript.DockRegion.LEFT, "LEFT"], ["panel_retarget_preview", "Retarget Preview", DockPanelScript.DockRegion.RIGHT, "RIGHT"],
		["panel_viewport", "2D Canvas Viewport", DockPanelScript.DockRegion.CENTER, "CENTER"],
		["panel_project_hub", "Project Play Hub", DockPanelScript.DockRegion.CENTER, "CENTER"],
		["panel_facing_grid", "Facing Grid Directions", DockPanelScript.DockRegion.CENTER, "CENTER"], ["panel_weapon_wizard", "Weapon Authoring Wizard", DockPanelScript.DockRegion.CENTER, "CENTER"], ["panel_character_creator", "Character Creator", DockPanelScript.DockRegion.CENTER, "CENTER"], ["panel_media_authoring", "Media Authoring", DockPanelScript.DockRegion.CENTER, "CENTER"], ["panel_animation_composition", "Animation Composition", DockPanelScript.DockRegion.CENTER, "CENTER"], ["panel_motion_library", "Motion Library & Polish", DockPanelScript.DockRegion.CENTER, "CENTER"], ["panel_runtime_delivery", "Runtime Preview & QA", DockPanelScript.DockRegion.CENTER, "CENTER"], ["panel_pipeline_collaboration", "Pipeline & Collaboration", DockPanelScript.DockRegion.CENTER, "CENTER"], ["panel_presentation", "Presentation & Approval", DockPanelScript.DockRegion.CENTER, "CENTER"], ["panel_batch_export", "Batch Export", DockPanelScript.DockRegion.CENTER, "CENTER"], ["panel_quality_dashboard", "Quality & Recovery", DockPanelScript.DockRegion.CENTER, "CENTER"], ["panel_review_package", "Review Package", DockPanelScript.DockRegion.CENTER, "CENTER"],
		["panel_inspector", "Inspector & Properties", DockPanelScript.DockRegion.RIGHT, "RIGHT"],
		["panel_timeline", "Animation Timeline", DockPanelScript.DockRegion.BOTTOM, "BOTTOM"],
		["panel_diagnostics", "Diagnostics & Logs", DockPanelScript.DockRegion.BOTTOM, "BOTTOM"]
	]
	for p_info in panels:
		var p := _create_dock_panel(p_info[0] as String, p_info[1] as String, p_info[2] as int)
		mgr.call("register_panel", p, p_info[3] as String)
func _create_dock_panel(pid: String, title: String, region: int) -> Control:
	var p: Control = DockPanelScript.new()
	p.name = pid
	p.set("panel_id", pid)
	p.call("set_panel_title", title)
	p.set("current_region", region)
	if pid == "panel_diagnostics" and DiagDrawerScene != null:
		var drawer := DiagDrawerScene.instantiate() as Control
		drawer.name = "DiagnosticsDrawer"
		p.call("add_content", drawer)
		if drawer.has_signal("source_navigated"):
			drawer.connect("source_navigated", _on_diagnostics_source_navigated)
	elif pid == "panel_facing_grid" and FacingDirectionSetEditorScene != null:
		var direction_editor := FacingDirectionSetEditorScene.instantiate() as Control
		direction_editor.name = "FacingDirectionSetEditor"
		p.call("add_content", direction_editor)
	elif pid == "panel_pose_library" and PoseLibraryPanelScene != null:
		p.call("add_content", PoseLibraryPanelScene.instantiate() as Control)
	elif pid == "panel_retarget_preview" and RetargetPreviewPanelScene != null:
		p.call("add_content", RetargetPreviewPanelScene.instantiate() as Control)
	elif pid == "panel_assets" and AssetBrowserScene != null: p.call("add_content", AssetBrowserScene.instantiate() as Control)
	elif pid == "panel_hierarchy":
		var hierarchy := RigHierarchyEditorScript.new() as Control
		hierarchy.name = "RigHierarchyEditor"
		hierarchy.call("bind_selection", document_selection)
		p.call("add_content", hierarchy)
	elif pid == "panel_viewport":
		var viewport := AuthoringCanvasViewportScript.new() as Control
		viewport.name = "AuthoringCanvasViewport"
		viewport.call("bind_selection", document_selection)
		p.call("add_content", viewport)
	elif pid == "panel_weapon_wizard" and WeaponAuthoringWizardScene != null:
		p.call("add_content", WeaponAuthoringWizardScene.instantiate() as Control)
	elif pid == "panel_character_creator" and CharacterCreatorPanelScene != null: p.call("add_content", CharacterCreatorPanelScene.instantiate() as Control)
	elif pid == "panel_project_hub" and ProjectHubPanelScene != null: p.call("add_content", ProjectHubPanelScene.instantiate() as Control)
	elif pid == "panel_media_authoring" and MediaAuthoringPanelScene != null: p.call("add_content", MediaAuthoringPanelScene.instantiate() as Control)
	elif pid == "panel_animation_composition" and AnimationCompositionPanelScene != null: p.call("add_content", AnimationCompositionPanelScene.instantiate() as Control)
	elif pid == "panel_motion_library":
		var motion_library := MotionLibraryPanelScript.new() as Control
		motion_library.name = "MotionLibraryPanel"
		p.call("add_content", motion_library)
	elif pid == "panel_runtime_delivery":
		var runtime_delivery := RuntimeDeliveryPanelScript.new() as Control
		runtime_delivery.name = "RuntimeDeliveryPanel"
		p.call("add_content", runtime_delivery)
	elif pid == "panel_pipeline_collaboration":
		var pipeline_collaboration := PipelineCollaborationPanelScript.new() as Control
		pipeline_collaboration.name = "PipelineCollaborationPanel"
		p.call("add_content", pipeline_collaboration)
	elif pid == "panel_presentation":
		var presentation := PresentationPanelScript.new() as Control
		presentation.name = "PresentationPanel"
		p.call("add_content", presentation)
	elif pid == "panel_batch_export" and BatchExportPanelScene != null: p.call("add_content", BatchExportPanelScene.instantiate() as Control)
	elif pid == "panel_quality_dashboard" and QualityDashboardPanelScene != null: p.call("add_content", QualityDashboardPanelScene.instantiate() as Control)
	elif pid == "panel_review_package":
		var review := ReviewPackagePanelScript.new() as Control
		review.name = "ReviewPackagePanel"
		p.call("add_content", review)
	elif pid == "panel_inspector":
		var inspector := AuthoringInspectorScript.new() as Control
		inspector.name = "AuthoringInspector"
		inspector.call("bind_selection", document_selection)
		p.call("add_content", inspector)
	elif pid == "panel_timeline":
		var timeline := AnimationTimelineEditorScript.new() as Control
		timeline.name = "AnimationTimelineEditor"
		timeline.call("bind_selection", document_selection)
		p.call("add_content", timeline)
	return p
func _setup_workspace_manager() -> void:
	if WorkspaceManager != null:
		WorkspaceManager.call("bind_dock_layout_manager", get_dock_layout_manager())
		get_dock_layout_manager().call("activate_panel", "panel_project_hub")
		if WorkspaceManager.has_signal("workspace_changed") and not WorkspaceManager.workspace_changed.is_connected(_on_workspace_changed):
			WorkspaceManager.workspace_changed.connect(_on_workspace_changed)
func _setup_menu_header() -> void:
	if preset_option_button != null:
		preset_option_button.clear()
		for preset in [DockLayoutManagerScript.PRESET_DEFAULT, DockLayoutManagerScript.PRESET_CHARACTER_CREATOR, DockLayoutManagerScript.PRESET_RIGGING, DockLayoutManagerScript.PRESET_ANIMATION, DockLayoutManagerScript.PRESET_MINIMAL]:
			preset_option_button.add_item(preset)
		if not preset_option_button.item_selected.is_connected(_on_preset_option_selected):
			preset_option_button.item_selected.connect(_on_preset_option_selected)
	if workspace_option_button != null and WorkspaceManager != null:
		workspace_option_button.clear()
		for wid in WorkspaceManager.call("get_registered_workspace_ids") as Array:
			var ws_title: String = WorkspaceManager.call("get_workspace_title", wid as String) as String
			workspace_option_button.add_item(ws_title)
		if not workspace_option_button.item_selected.is_connected(_on_workspace_option_selected):
			workspace_option_button.item_selected.connect(_on_workspace_option_selected)
	if command_palette_button != null and not command_palette_button.pressed.is_connected(toggle_command_palette):
		command_palette_button.pressed.connect(toggle_command_palette)
func _setup_shortcut_commands() -> void:
	if ShortcutRegistry == null:
		return
	ShortcutRegistry.register_command("app.open_command_palette", "Command Palette: Open", "General", "Ctrl+Shift+P", open_command_palette, ["palette", "search", "shortcut"])
	ShortcutRegistry.register_command("file.save", "File: Save Project", "File", "Ctrl+S", Callable(project_actions, "save_current"), ["save", "file"])
	ShortcutRegistry.register_command("file.save_as", "File: Save Project As", "File", "Ctrl+Shift+S", Callable(project_actions, "open_save_as"), ["save", "as", "file"])
	ShortcutRegistry.register_command("file.close", "File: Close Project", "File", "Ctrl+W", _on_cmd_close_project, ["close", "file"])
	ShortcutRegistry.register_command("edit.undo", "Edit: Undo", "Edit", "Ctrl+Z", Callable(project_actions, "undo_current"), ["undo", "revert"])
	ShortcutRegistry.register_command("edit.redo", "Edit: Redo", "Edit", "Ctrl+Y", Callable(project_actions, "redo_current"), ["redo", "repeat"])
	ShortcutRegistry.register_command("workspace.switch_assets", "Workspace: Switch to Project Assets", "Workspace", "", Callable(self, "_switch_ws").bind("project_assets"), ["workspace", "assets"])
	ShortcutRegistry.register_command("workspace.switch_character", "Workspace: Switch to Character Creator", "Workspace", "", Callable(self, "_switch_ws").bind("character_creator"), ["workspace", "character"])
	ShortcutRegistry.register_command("workspace.switch_animation", "Workspace: Switch to Animation Studio", "Workspace", "", Callable(self, "_switch_ws").bind("animation_studio"), ["workspace", "animation"])
	ShortcutRegistry.register_command("runtime.open_preview", "Runtime: Open Preview & QA", "Runtime", "", Callable(self, "_open_production_panel").bind("panel_runtime_delivery"), ["runtime", "preview", "qa", "export"])
	ShortcutRegistry.register_command("animation.open_motion_library", "Animation: Open Motion Library", "Animation", "", Callable(self, "_open_production_panel").bind("panel_motion_library"), ["motion", "library", "retarget", "secondary"])
	ShortcutRegistry.register_command("pipeline.open_collaboration", "Pipeline: Open Collaboration", "Pipeline", "", Callable(self, "_open_production_panel").bind("panel_pipeline_collaboration"), ["git", "snapshot", "watch", "asset", "pack"])
	ShortcutRegistry.register_command("presentation.open_approval", "Presentation: Open Approval Package", "Presentation", "", Callable(self, "_open_production_panel").bind("panel_presentation"), ["turntable", "viseme", "outfit", "approval"])
	ShortcutRegistry.register_command("view.toggle_diagnostics", "View: Toggle Diagnostics Drawer", "View", "Ctrl+Shift+D", _toggle_diagnostics_drawer, ["diagnostics", "drawer", "logs"])
	ShortcutRegistry.register_command("view.toggle_theme", "View: Toggle Studio/Classic Appearance", "View", "Ctrl+Shift+T", _cmd_toggle_theme, ["theme", "obsidian", "classic", "appearance"])
	ShortcutRegistry.register_command("view.set_dpi_scale", "View: Cycle DPI Scale", "View", "Ctrl+Shift+U", _cmd_cycle_dpi_scale, ["dpi", "scale", "ui", "display"])
	ShortcutRegistry.register_command("focus.next_panel", "Focus: Next Panel", "View", "F6", func(): if FocusService != null: FocusService.cycle_panel_focus(true), ["focus", "panel", "next"])
	ShortcutRegistry.register_command("focus.prev_panel", "Focus: Previous Panel", "View", "Shift+F6", func(): if FocusService != null: FocusService.cycle_panel_focus(false), ["focus", "panel", "prev"])
	ShortcutRegistry.register_command("focus.menu_bar", "Focus: Menu Bar", "View", "F10", func(): if FocusService != null: FocusService.focus_menu_bar(menu_bar), ["focus", "menu", "bar"])
	ShortcutRegistry.register_command("focus.clear", "Focus: Clear Focus", "View", "Escape", func(): if FocusService != null: FocusService.clear_focus(), ["focus", "clear", "escape"])
func _setup_focus_framework() -> void:
	if FocusService == null:
		return
	if menu_bar != null:
		FocusService.register_focus_group("menu_bar", menu_bar)
	for pid in ["panel_assets", "panel_hierarchy", "panel_viewport", "panel_project_hub", "panel_facing_grid", "panel_weapon_wizard", "panel_character_creator", "panel_media_authoring", "panel_animation_composition", "panel_motion_library", "panel_runtime_delivery", "panel_pipeline_collaboration", "panel_presentation", "panel_batch_export", "panel_quality_dashboard", "panel_review_package", "panel_inspector", "panel_timeline", "panel_diagnostics"]:
		var p := get_panel(pid)
		if p != null:
			FocusService.register_focus_group(pid, p)
func _toggle_diagnostics_drawer() -> void:
	var mgr := get_dock_layout_manager()
	if mgr != null:
		var show: bool = not mgr.call("is_panel_visible", "panel_diagnostics")
		mgr.call("set_panel_visible", "panel_diagnostics", show)
		if show: mgr.call("activate_panel", "panel_diagnostics")
		set_status_message("Diagnostics drawer " + ("shown" if show else "hidden"))
func _cmd_toggle_theme() -> void:
	if ThemeService != null:
		ThemeService.toggle_theme_mode()
		set_status_message("Appearance: " + ThemeService.get_appearance_mode_name())
func _cmd_cycle_dpi_scale() -> void:
	if ThemeService != null:
		var scale := ThemeService.cycle_dpi_scale()
		set_status_message("DPI scale set to: %.0f%%" % (scale * 100.0))
func _on_diagnostics_source_navigated(source_path: String, line_number: int) -> void:
	set_status_message("Navigating to source: %s:%d" % [source_path, line_number])
func _setup_app_state_listeners() -> void:
	if AppState != null:
		if not AppState.dirty_state_changed.is_connected(_on_dirty_state_changed):
			AppState.dirty_state_changed.connect(_on_dirty_state_changed)
		_on_dirty_state_changed(AppState.is_dirty())
func _on_dirty_state_changed(_is_dirty: bool) -> void:
	if get_window() != null and AppState != null:
		get_window().title = AppState.get_formatted_title()
	set_status_message(_current_status)
func _handle_close_request() -> void:
	if AppState != null and AppState.is_dirty() and unsaved_changes_dialog != null:
		get_tree().set_auto_accept_quit(false)
		unsaved_changes_dialog.call("prompt", "You have unsaved changes in your current project.\nDo you want to save before closing?", Callable(self, "_on_close_dialog_choice"))
	else:
		get_tree().quit()
func _on_close_dialog_choice(choice: int) -> void:
	if choice == UnsavedDialogScript.Choice.SAVE:
		var report: Dictionary = project_actions.call("save_current") as Dictionary if project_actions != null else {}
		if report.get("success", false): get_tree().quit()
	elif choice == UnsavedDialogScript.Choice.DISCARD:
		if AppState != null:
			AppState.clear_dirty()
		get_tree().quit()
func _on_cmd_close_project() -> void:
	if AppState != null and AppState.is_dirty() and unsaved_changes_dialog != null:
		unsaved_changes_dialog.call("prompt", "Close current project?", Callable(self, "_on_close_project_choice"))
	else:
		if AppState != null:
			AppState.close_project()
		set_status_message("Project closed.")
func _on_close_project_choice(choice: int) -> void:
	if choice == UnsavedDialogScript.Choice.SAVE:
		var report: Dictionary = project_actions.call("save_current") as Dictionary if project_actions != null else {}
		if report.get("success", false) and AppState != null:
			AppState.close_project()
			set_status_message("Project saved and closed.")
	elif choice == UnsavedDialogScript.Choice.DISCARD:
		if AppState != null:
			AppState.close_project()
		set_status_message("Project closed without saving.")

func _switch_ws(ws_id: String) -> void:
	if WorkspaceManager != null:
		WorkspaceManager.call("switch_workspace", ws_id)


func _open_production_panel(panel_id: String) -> void:
	if WorkspaceManager != null: WorkspaceManager.call("switch_workspace", "preview_export" if panel_id != "panel_motion_library" else "animation_studio")
	var manager := get_dock_layout_manager()
	if manager != null:
		manager.call("set_panel_visible", panel_id, true)
		manager.call("activate_panel", panel_id)

func _on_preset_option_selected(index: int) -> void:
	if preset_option_button != null:
		select_workspace_preset(preset_option_button.get_item_text(index))

func _on_workspace_option_selected(index: int) -> void:
	if workspace_option_button != null and WorkspaceManager != null:
		var ids: Array = WorkspaceManager.call("get_registered_workspace_ids")
		if index >= 0 and index < ids.size():
			WorkspaceManager.call("switch_workspace", ids[index] as String)

func _on_workspace_changed(new_id: String, _old_id: String) -> void:
	workspace_changed.emit(new_id)
	var ws_title: String = WorkspaceManager.call("get_workspace_title", new_id) as String if WorkspaceManager != null else new_id
	set_status_message("Switched workspace to: " + ws_title)
	_sync_option_buttons()

func _sync_option_buttons() -> void:
	if WorkspaceManager != null and workspace_option_button != null:
		var active_id: String = WorkspaceManager.call("get_active_workspace_id") as String
		var ids: Array = WorkspaceManager.call("get_registered_workspace_ids")
		var idx := ids.find(active_id)
		if idx >= 0:
			workspace_option_button.select(idx)
	var mgr := get_dock_layout_manager()
	if mgr != null and preset_option_button != null:
		var active_preset := mgr.call("get_active_preset_name") as String
		for i in range(preset_option_button.item_count):
			if preset_option_button.get_item_text(i) == active_preset:
				preset_option_button.select(i)
				break
