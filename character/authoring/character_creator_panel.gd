# CharacterCreatorPanel -- Manual image-layer character authoring bound to project data.
class_name CharacterCreatorPanel
extends Control

const ModelScript = preload("res://character/authoring/character_creator_model.gd")
const SessionScript = preload("res://character/authoring/character_project_session.gd")
signal project_session_ready(session)
@onready var name_input: LineEdit = $Margin/Root/Content/Picker/PickerMargin/PickerVBox/NameGroup/Name
@onready var apply_button: Button = $Margin/Root/Header/Apply
@onready var slot_select: OptionButton = $Margin/Root/Content/Picker/PickerMargin/PickerVBox/Slot
@onready var search_input: LineEdit = $Margin/Root/Content/Picker/PickerMargin/PickerVBox/Search
@onready var part_list: ItemList = $Margin/Root/Content/Picker/PickerMargin/PickerVBox/PartList
@onready var import_button: Button = $Margin/Root/Content/Picker/PickerMargin/PickerVBox/Import
@onready var import_folder_button: Button = $Margin/Root/Content/Picker/PickerMargin/PickerVBox/ImportFolder
@onready var repair_missing_button: Button = $Margin/Root/Content/Picker/PickerMargin/PickerVBox/RepairMissing
@onready var equip_button: Button = $Margin/Root/Content/Picker/PickerMargin/PickerVBox/EditActions/Equip
@onready var unequip_button: Button = $Margin/Root/Content/Picker/PickerMargin/PickerVBox/EditActions/Unequip
@onready var preview: Control = $Margin/Root/Content/PreviewCard/PreviewMargin/PreviewVBox/Preview
@onready var layer_summary: Label = $Margin/Root/Content/PreviewCard/PreviewMargin/PreviewVBox/LayerSummary
@onready var status_label: Label = $Margin/Root/Status
@onready var file_dialog: FileDialog = $ImportFileDialog
@onready var folder_dialog: FileDialog = $ImportFolderDialog
@onready var replace_dialog: FileDialog = $ReplaceFileDialog
@onready var repair_dialog: FileDialog = $RepairFolderDialog
@onready var undo_button: Button = $Margin/Root/Content/Picker/PickerMargin/PickerVBox/History/Undo
@onready var redo_button: Button = $Margin/Root/Content/Picker/PickerMargin/PickerVBox/History/Redo
@onready var history_label: Label = $Margin/Root/Content/Picker/PickerMargin/PickerVBox/HistoryLabel
@onready var template_select: OptionButton = $Margin/Root/Content/Picker/PickerMargin/PickerVBox/WizardSetup/TemplateRow/Template
@onready var apply_template_button: Button = $Margin/Root/Content/Picker/PickerMargin/PickerVBox/WizardSetup/TemplateRow/ApplyTemplate
@onready var canvas_width: SpinBox = $Margin/Root/Content/Picker/PickerMargin/PickerVBox/WizardSetup/CanvasRow/CanvasWidth
@onready var canvas_height: SpinBox = $Margin/Root/Content/Picker/PickerMargin/PickerVBox/WizardSetup/CanvasRow/CanvasHeight
@onready var pixel_scale: SpinBox = $Margin/Root/Content/Picker/PickerMargin/PickerVBox/WizardSetup/CanvasRow/PixelScale
@onready var apply_canvas_button: Button = $Margin/Root/Content/Picker/PickerMargin/PickerVBox/WizardSetup/CanvasRow/ApplyCanvas
@onready var layer_list: ItemList = $Margin/Root/Content/Picker/PickerMargin/PickerVBox/LayerEditor/LayerList
@onready var layer_move_up: Button = $Margin/Root/Content/Picker/PickerMargin/PickerVBox/LayerEditor/LayerActions/MoveUp
@onready var layer_move_down: Button = $Margin/Root/Content/Picker/PickerMargin/PickerVBox/LayerEditor/LayerActions/MoveDown
@onready var layer_visibility: Button = $Margin/Root/Content/Picker/PickerMargin/PickerVBox/LayerEditor/LayerActions/Visibility
@onready var layer_lock: Button = $Margin/Root/Content/Picker/PickerMargin/PickerVBox/LayerEditor/LayerActions/Lock
@onready var layer_solo: Button = $Margin/Root/Content/Picker/PickerMargin/PickerVBox/LayerEditor/LayerActions/Solo
@onready var layer_duplicate: Button = $Margin/Root/Content/Picker/PickerMargin/PickerVBox/LayerEditor/LayerActions/Duplicate
@onready var layer_replace: Button = $Margin/Root/Content/Picker/PickerMargin/PickerVBox/LayerEditor/LayerActions/Replace
@onready var layer_delete: Button = $Margin/Root/Content/Picker/PickerMargin/PickerVBox/LayerEditor/LayerActions/Delete
@onready var pos_x: SpinBox = $Margin/Root/Content/Picker/PickerMargin/PickerVBox/LayerEditor/Transform/PosX
@onready var pos_y: SpinBox = $Margin/Root/Content/Picker/PickerMargin/PickerVBox/LayerEditor/Transform/PosY
@onready var scale_x: SpinBox = $Margin/Root/Content/Picker/PickerMargin/PickerVBox/LayerEditor/Transform/ScaleX
@onready var scale_y: SpinBox = $Margin/Root/Content/Picker/PickerMargin/PickerVBox/LayerEditor/Transform/ScaleY
@onready var rotation_input: SpinBox = $Margin/Root/Content/Picker/PickerMargin/PickerVBox/LayerEditor/Transform/Rotation
@onready var pivot_x: SpinBox = $Margin/Root/Content/Picker/PickerMargin/PickerVBox/LayerEditor/Transform/PivotX
@onready var pivot_y: SpinBox = $Margin/Root/Content/Picker/PickerMargin/PickerVBox/LayerEditor/Transform/PivotY
@onready var opacity: SpinBox = $Margin/Root/Content/Picker/PickerMargin/PickerVBox/LayerEditor/Transform/Opacity
@onready var tint: ColorPickerButton = $Margin/Root/Content/Picker/PickerMargin/PickerVBox/LayerEditor/Tint

var model = null
var session = null
var _setting_name := false
var _setting_layer_controls := false
var _setting_canvas_controls := false

func _ready() -> void:
	search_input.text_changed.connect(func(_text): refresh_parts())
	slot_select.item_selected.connect(func(_index): refresh_parts())
	part_list.item_selected.connect(func(_index): _refresh_selection_state())
	part_list.item_activated.connect(_on_part_activated)
	import_button.pressed.connect(_on_import_pressed)
	import_folder_button.pressed.connect(func(): folder_dialog.popup_centered_ratio(0.72))
	repair_missing_button.pressed.connect(func(): repair_dialog.popup_centered_ratio(0.72))
	equip_button.pressed.connect(_on_equip_pressed)
	unequip_button.pressed.connect(_on_unequip_pressed)
	undo_button.pressed.connect(undo_edit)
	redo_button.pressed.connect(redo_edit)
	$Margin/Root/Content/PreviewCard/PreviewMargin/PreviewVBox/PreviewTools/ZoomOut.pressed.connect(preview.zoom_out)
	$Margin/Root/Content/PreviewCard/PreviewMargin/PreviewVBox/PreviewTools/Reset.pressed.connect(preview.reset_view)
	$Margin/Root/Content/PreviewCard/PreviewMargin/PreviewVBox/PreviewTools/ZoomIn.pressed.connect(preview.zoom_in)
	$Margin/Root/Content/PreviewCard/PreviewMargin/PreviewVBox/PreviewTools/PixelGrid.toggled.connect(preview.set_pixel_grid)
	apply_button.pressed.connect(_on_apply_pressed)
	name_input.text_submitted.connect(func(_text): commit_pending_edits())
	name_input.focus_exited.connect(commit_pending_edits)
	file_dialog.file_selected.connect(_on_file_selected)
	folder_dialog.dir_selected.connect(_on_folder_selected)
	replace_dialog.file_selected.connect(_on_replace_file_selected)
	repair_dialog.dir_selected.connect(_on_repair_folder_selected)
	apply_template_button.pressed.connect(_on_apply_template_pressed)
	apply_canvas_button.pressed.connect(_on_apply_canvas_pressed)
	layer_list.item_selected.connect(_on_layer_selected)
	if layer_list.has_signal("files_dropped"): layer_list.connect("files_dropped", _on_layer_list_files_dropped)
	layer_move_up.pressed.connect(func(): _move_selected_layer(-1))
	layer_move_down.pressed.connect(func(): _move_selected_layer(1))
	layer_visibility.pressed.connect(_toggle_selected_layer_visibility)
	layer_lock.pressed.connect(_toggle_selected_layer_lock)
	layer_solo.pressed.connect(_solo_selected_layer)
	layer_duplicate.pressed.connect(_duplicate_selected_layer)
	layer_replace.pressed.connect(func(): if not _selected_layer_id().is_empty(): replace_dialog.popup_centered_ratio(0.72))
	layer_delete.pressed.connect(_delete_selected_layer)
	pos_x.value_changed.connect(func(_value): _commit_layer_position())
	pos_y.value_changed.connect(func(_value): _commit_layer_position())
	scale_x.value_changed.connect(func(_value): _commit_layer_scale())
	scale_y.value_changed.connect(func(_value): _commit_layer_scale())
	rotation_input.value_changed.connect(func(_value): _commit_layer_rotation())
	pivot_x.value_changed.connect(func(_value): _commit_layer_pivot())
	pivot_y.value_changed.connect(func(_value): _commit_layer_pivot())
	opacity.value_changed.connect(func(_value): _commit_layer_opacity())
	tint.color_changed.connect(_commit_layer_tint)
	if preview.has_signal("files_dropped"): preview.connect("files_dropped", _on_preview_files_dropped)
	if AppState != null:
		AppState.project_opened.connect(open_project_path)
		AppState.project_closed.connect(_on_project_closed)
	if CommandService != null and not CommandService.undo_stack_changed.is_connected(_on_document_history_changed):
		CommandService.undo_stack_changed.connect(_on_document_history_changed)
	if AppState != null and AppState.is_project_loaded():
		call_deferred("open_project_path", AppState.get_project_path())
	else:
		_set_editing_enabled(false)
		_refresh_status("Create or open a project to begin importing character art.")

func open_project_path(path: String) -> Dictionary:
	if session != null:
		session.queue_free()
		session = null
	model = null
	var next_session = SessionScript.new()
	add_child(next_session)
	var report: Dictionary = next_session.open_project(path)
	if not report.get("success", false):
		next_session.queue_free()
		_set_editing_enabled(false)
		_bind_asset_browser()
		_refresh_status(str(report.get("errors", ["Project setup failed."])[0]))
		return report
	session = next_session
	model = session.model
	session.session_changed.connect(_on_session_changed)
	_populate_slots(session.get_slots())
	_populate_templates()
	_refresh_canvas_controls()
	_set_character_name(model.assembly.display_name)
	_set_editing_enabled(true)
	refresh_parts()
	refresh_layers()
	_refresh_preview()
	_bind_asset_browser()
	_refresh_status("Ready. Import artwork into a layer slot to build the character.")
	project_session_ready.emit(session)
	return report

func bind_context(part_registry, slot_registry, body_types: Array, weapons: Array = [], character_id: String = "character", display_name: String = "Character", body_type_id: String = "") -> Dictionary:
	model = ModelScript.new()
	model.configure(part_registry, slot_registry, body_types, weapons)
	model.changed.connect(_on_manual_model_changed)
	var selected_body := body_type_id
	if selected_body.is_empty() and not body_types.is_empty(): selected_body = body_types[0].body_type_id
	var report: Dictionary = model.create_character(character_id, display_name, selected_body)
	_populate_slots(slot_registry.list_slots() if slot_registry != null else [])
	_populate_templates()
	_set_character_name(display_name)
	_set_editing_enabled(true)
	refresh_parts()
	refresh_layers()
	_refresh_preview()
	_refresh_status("Character ready." if report.get("success", false) else str(report.get("errors", ["Character setup failed."])[0]))
	return report

func import_part(path: String, slot_id: String = "") -> Dictionary:
	if session == null: return _failure("Open a saved project before importing artwork.")
	var target_slot := slot_id if not slot_id.is_empty() else _selected_slot_id()
	var report: Dictionary = session.import_part(path, target_slot)
	if report.get("success", false):
		refresh_parts()
		refresh_layers()
		_select_part(str(report.part_id))
		_refresh_preview()
		var duplicates: Array = report.get("duplicate_asset_ids", [])
		_refresh_status("Imported and equipped %s%s." % [path.get_file(), " · duplicate artwork detected" if not duplicates.is_empty() else ""])
	else:
		_refresh_status(str(report.get("errors", ["Image import failed."])[0]))
	return report

func save_project() -> Dictionary:
	commit_pending_edits()
	if model == null: return _failure("Open a character project before saving.")
	var report: Dictionary = session.save_project() if session != null else model.assembly.validate()
	_refresh_status("Character project saved." if report.get("success", false) else str(report.get("errors", ["Save failed."])[0]))
	return report

func refresh_parts() -> void:
	if model == null or part_list == null: return
	var selected_id := _selected_part_id()
	part_list.clear()
	var filters := {"query": search_input.text}
	var slot_id := _selected_slot_id()
	if not slot_id.is_empty(): filters["slot_id"] = slot_id
	var equipped: Array = model.assembly.get_equipped_part_ids()
	for part in model.browse_parts(filters):
		var label: String = ("✓  " if part.part_id in equipped else "    ") + str(part.display_name)
		var icon: Texture2D = null
		if session != null:
			var asset: Dictionary = session.get_part_asset(part.part_id)
			if not asset.is_empty(): icon = session.thumbnail_cache.get_thumbnail(asset, Vector2i(48, 48))
		part_list.add_item(label, icon)
		part_list.set_item_metadata(part_list.item_count - 1, part.part_id)
	_select_part(selected_id)
	_refresh_selection_state()


func refresh_layers() -> void:
	if layer_list == null:
		return
	var selected_id := _selected_layer_id()
	layer_list.clear()
	if session == null or model == null:
		_refresh_layer_editor()
		return
	for layer in session.get_layer_entries():
		var entry: Dictionary = layer
		var part_id := str(entry.get("part_id", ""))
		var state: Dictionary = entry.get("state", {})
		var label := str(entry.get("name", "Layer")) + " · " + str(entry.get("slot_id", ""))
		if bool(entry.get("missing", false)): label = "⚠ Missing · " + label
		elif not bool(entry.get("visible", true)): label = "◌ Hidden · " + label
		elif bool(state.get("locked", false)): label = "▣ Locked · " + label
		var icon: Texture2D = null
		var asset: Dictionary = entry.get("asset", {})
		if not asset.is_empty(): icon = session.thumbnail_cache.get_thumbnail(asset, Vector2i(40, 40))
		layer_list.add_item(label, icon)
		layer_list.set_item_metadata(layer_list.item_count - 1, part_id)
	_select_layer(selected_id)
	_refresh_layer_editor()

func get_model(): return model
func get_session(): return session
func get_preview_loaded_layer_count() -> int: return preview.get_loaded_layer_count() if preview != null else 0


func _populate_templates() -> void:
	if template_select == null: return
	template_select.clear()
	var options: Array = session.get_slot_template_options() if session != null else []
	for option in options:
		var data: Dictionary = option
		template_select.add_item(str(data.get("name", "Import Template")))
		template_select.set_item_metadata(template_select.item_count - 1, str(data.get("id", "blank")))
		var index := template_select.item_count - 1
		if session != null and str(data.get("id", "")) == session.get_selected_slot_template(): template_select.select(index)


func _refresh_canvas_controls() -> void:
	if session == null: return
	_setting_canvas_controls = true
	var settings: Dictionary = session.get_canvas_settings()
	canvas_width.value = int(settings.get("width", 512))
	canvas_height.value = int(settings.get("height", 512))
	pixel_scale.value = float(settings.get("pixel_scale", 1.0))
	_setting_canvas_controls = false


func _on_apply_template_pressed() -> void:
	if session == null or template_select.selected < 0: return
	var report: Dictionary = session.apply_slot_template(str(template_select.get_item_metadata(template_select.selected)))
	if report.get("success", false):
		_populate_slots(session.get_slots())
		_refresh_canvas_controls()
		_refresh_status("Slot template applied. Now import your artwork.")
	else:
		_refresh_status(str(report.get("errors", ["Template could not be applied."])[0]))


func _on_apply_canvas_pressed() -> void:
	if session == null: return
	if session.set_canvas_settings(int(canvas_width.value), int(canvas_height.value), pixel_scale.value):
		_refresh_preview()
		_refresh_status("Canvas settings updated.")
	else:
		_refresh_status("Canvas settings were unchanged or the project is read-only.")

func _populate_slots(slots: Array) -> void:
	slot_select.clear()
	for slot in slots:
		slot_select.add_item(slot.display_name)
		slot_select.set_item_metadata(slot_select.item_count - 1, slot.slot_id)
	if slot_select.item_count > 0: slot_select.select(0)

func _on_import_pressed() -> void:
	if _selected_slot_id().is_empty():
		_refresh_status("Choose a layer slot before importing artwork.")
		return
	file_dialog.popup_centered_ratio(0.72)

func _on_file_selected(path: String) -> void: import_part(path)


func _on_folder_selected(path: String) -> void:
	if session == null: return
	var report: Dictionary = session.import_folder(path)
	if not report.get("imported", []).is_empty():
		refresh_parts()
		refresh_layers()
		_refresh_preview()
		var skipped := (report.get("unmatched", []) as Array).size()
		_refresh_status("Imported %d artwork layer%s by filename%s." % [report.get("imported", []).size(), "s" if report.get("imported", []).size() != 1 else "", " · %d need a slot name" % skipped if skipped > 0 else ""])
	else:
		_refresh_status(str(report.get("errors", ["No artwork was imported."])[0]))


func _on_replace_file_selected(path: String) -> void:
	if session == null: return
	var layer_id := _selected_layer_id()
	var report: Dictionary = session.replace_layer_art(layer_id, path)
	if report.get("success", false):
		refresh_parts()
		refresh_layers()
		_refresh_preview()
		_refresh_status("Layer artwork replaced.")
	else:
		_refresh_status(str(report.get("errors", ["Artwork could not be replaced."])[0]))


func _on_repair_folder_selected(path: String) -> void:
	if session == null: return
	var report: Dictionary = session.repair_missing_artwork(path)
	if report.get("success", false):
		refresh_parts()
		refresh_layers()
		_refresh_preview()
		_refresh_status("Repaired %d missing artwork file%s." % [int(report.get("repaired", 0)), "s" if int(report.get("repaired", 0)) != 1 else ""])
	else:
		_refresh_status(str(report.get("errors", ["Artwork could not be repaired."])[0]))


func _on_preview_files_dropped(paths: Array) -> void:
	if session == null: return
	var files: Array = []
	var folders: Array = []
	for entry in paths:
		var path := str(entry)
		if _is_folder_path(path): folders.append(path)
		else: files.append(path)
	var imported: Array = []
	var errors: Array = []
	for folder in folders:
		var folder_report: Dictionary = session.import_folder(str(folder))
		imported.append_array(folder_report.get("imported", []))
		errors.append_array(folder_report.get("errors", []))
	if not files.is_empty():
		var plan: Dictionary = session.map_files_to_slots(files)
		var explicit_slot := _selected_slot_id() if files.size() == 1 and (plan.get("mapped", []) as Array).is_empty() else ""
		var file_report: Dictionary = session.import_files_by_slot(files, explicit_slot)
		imported.append_array(file_report.get("imported", []))
		errors.append_array(file_report.get("errors", []))
	if not imported.is_empty():
		refresh_parts()
		refresh_layers()
		_refresh_preview()
		_refresh_status("Dropped artwork imported and mapped by filename%s." % (" from folder" if not folders.is_empty() else ""))
	else:
		_refresh_status(str(errors[0]) if not errors.is_empty() else "Dropped files could not be mapped to layer slots.")


func _on_layer_list_files_dropped(paths: Array) -> void:
	if session == null or paths.is_empty():
		return
	var selected_layer := _selected_layer_id()
	if paths.size() == 1 and not _is_folder_path(str(paths[0])) and not selected_layer.is_empty():
		var replacement: Dictionary = session.replace_layer_art(selected_layer, str(paths[0]))
		if replacement.get("success", false):
			refresh_parts()
			refresh_layers()
			_refresh_preview()
			_refresh_status("Dropped artwork replaced the selected layer.")
		else:
			_refresh_status(str(replacement.get("errors", ["Dropped artwork could not replace the layer."])[0]))
		return
	_on_preview_files_dropped(paths)


func _is_folder_path(path: String) -> bool:
	var absolute := ProjectSettings.globalize_path(path) if path.begins_with("res://") or path.begins_with("user://") else path
	return DirAccess.dir_exists_absolute(absolute)

func _on_part_activated(index: int) -> void:
	if index >= 0: _equip_part(str(part_list.get_item_metadata(index)))

func _on_equip_pressed() -> void: _equip_part(_selected_part_id())

func _equip_part(part_id: String) -> void:
	if model == null or part_id.is_empty(): return
	var report: Dictionary = model.equip_part(part_id)
	_refresh_status("Part equipped." if report.get("success", false) else str(report.get("errors", ["Part could not be equipped."])[0]))
	refresh_parts()
	refresh_layers()
	_refresh_preview()

func _on_unequip_pressed() -> void:
	var part_id := _selected_part_id()
	if model != null and model.unequip_part(part_id):
		_refresh_status("Part unequipped.")
		refresh_parts()
		refresh_layers()
		_refresh_preview()
	else: _refresh_status("Select an equipped part to remove from the preview.")

func _on_layer_selected(_index: int) -> void:
	_refresh_layer_editor()
	_refresh_selection_state()


func _move_selected_layer(delta: int) -> void:
	var part_id := _selected_layer_id()
	if model != null and model.move_layer_by(part_id, delta):
		refresh_layers()
		_refresh_preview()
		_refresh_status("Layer order updated.")


func _toggle_selected_layer_visibility() -> void:
	var part_id := _selected_layer_id()
	if model == null or part_id.is_empty(): return
	var state: Dictionary = model.get_layer_state(part_id)
	if model.set_layer_visibility(part_id, not bool(state.get("visible", true))):
		refresh_layers()
		_refresh_preview()


func _toggle_selected_layer_lock() -> void:
	var part_id := _selected_layer_id()
	if model == null or part_id.is_empty(): return
	var state: Dictionary = model.get_layer_state(part_id)
	if model.set_layer_locked(part_id, not bool(state.get("locked", false))): refresh_layers()


func _solo_selected_layer() -> void:
	var part_id := _selected_layer_id()
	if model != null and model.solo_layer(part_id):
		refresh_layers()
		_refresh_preview()


func _duplicate_selected_layer() -> void:
	var part_id := _selected_layer_id()
	if session == null or part_id.is_empty(): return
	var report: Dictionary = session.duplicate_layer(part_id)
	if report.get("success", false):
		refresh_parts()
		refresh_layers()
		_select_layer(str(report.get("part_id", "")))
		_refresh_preview()
		_refresh_status("Layer duplicated.")
	else:
		_refresh_status(str(report.get("errors", ["Layer could not be duplicated."])[0]))


func _delete_selected_layer() -> void:
	var part_id := _selected_layer_id()
	if session == null or part_id.is_empty(): return
	var report: Dictionary = session.delete_layer(part_id)
	if report.get("success", false):
		refresh_parts()
		refresh_layers()
		_refresh_preview()
		_refresh_status("Layer deleted. Use Undo to restore it.")
	else:
		_refresh_status(str(report.get("errors", ["Layer could not be deleted."])[0]))


func _commit_layer_position() -> void:
	if _setting_layer_controls or model == null: return
	var id := _selected_layer_id()
	if not id.is_empty() and model.set_layer_position(id, Vector2(pos_x.value, pos_y.value)): _refresh_preview()


func _commit_layer_scale() -> void:
	if _setting_layer_controls or model == null: return
	var id := _selected_layer_id()
	if not id.is_empty() and model.set_layer_scale(id, Vector2(scale_x.value, scale_y.value)): _refresh_preview()


func _commit_layer_rotation() -> void:
	if _setting_layer_controls or model == null: return
	var id := _selected_layer_id()
	if not id.is_empty() and model.set_layer_rotation(id, rotation_input.value): _refresh_preview()


func _commit_layer_pivot() -> void:
	if _setting_layer_controls or model == null: return
	var id := _selected_layer_id()
	if not id.is_empty() and model.set_layer_pivot(id, Vector2(pivot_x.value, pivot_y.value)): _refresh_preview()


func _commit_layer_opacity() -> void:
	if _setting_layer_controls or model == null: return
	var id := _selected_layer_id()
	if not id.is_empty() and model.set_layer_opacity(id, opacity.value): _refresh_preview()


func _commit_layer_tint(next_tint: Color) -> void:
	if _setting_layer_controls or model == null: return
	var id := _selected_layer_id()
	if not id.is_empty() and model.set_layer_tint(id, next_tint): _refresh_preview()


func undo_edit() -> bool:
	if session != null and CommandService != null and CommandService.can_undo():
		var label := CommandService.get_undo_description()
		CommandService.undo()
		AppState.update_undo_dirty_state(CommandService.get_undo_count())
		_refresh_status("Undid " + label + ".")
		return true
	if model != null and model.undo(): _refresh_status("Undid character edit."); _refresh_preview(); refresh_parts(); refresh_layers(); return true
	return false

func redo_edit() -> bool:
	if session != null and CommandService != null and CommandService.can_redo():
		var label := CommandService.get_redo_description()
		CommandService.redo()
		AppState.update_undo_dirty_state(CommandService.get_undo_count())
		_refresh_status("Redid " + label + ".")
		return true
	if model != null and model.redo(): _refresh_status("Redid character edit."); _refresh_preview(); refresh_parts(); refresh_layers(); return true
	return false

func _on_apply_pressed() -> void: save_project()

func commit_pending_edits() -> void:
	if _setting_name or model == null: return
	var next_name := name_input.text.strip_edges()
	if next_name.is_empty():
		_set_character_name(model.assembly.display_name)
		_refresh_status("Character name cannot be empty.")
	elif session != null: session.set_character_name(next_name)
	else: model.assembly.display_name = next_name

func _on_session_changed(description: String) -> void:
	model = session.model if session != null else null
	refresh_parts()
	refresh_layers()
	_refresh_canvas_controls()
	_refresh_preview()
	_refresh_status(description + ".")


func _on_manual_model_changed(description: String) -> void:
	refresh_parts()
	refresh_layers()
	_refresh_preview()
	_refresh_status(description + ".")


func _refresh_preview() -> void:
	var layers: Array = session.get_preview_layers() if session != null else []
	if session != null: preview.set_canvas_settings(session.get_canvas_settings())
	preview.set_layers(layers)
	if layers.is_empty(): layer_summary.text = "0 layers equipped · imported artwork will appear here"
	else:
		var names: Array[String] = []
		for layer in layers: names.append(str(layer.slot_id).capitalize())
		layer_summary.text = "%d layer%s · %s" % [layers.size(), "s" if layers.size() != 1 else "", ", ".join(names)]


func _bind_asset_browser() -> void:
	var cursor: Node = self
	while cursor != null and not cursor.has_method("get_panel"): cursor = cursor.get_parent()
	if cursor == null: return
	var dock = cursor.call("get_panel", "panel_assets")
	var browser = dock.get_node_or_null("MainVBox/ContentContainer/AssetBrowser") if dock != null else null
	if browser == null: return
	var registry = session.asset_registry if session != null else null
	var thumbnails = session.thumbnail_cache if session != null else null
	browser.call("setup", registry, thumbnails)
	if browser.has_signal("asset_double_clicked") and not browser.is_connected("asset_double_clicked", _on_asset_double_clicked):
		browser.connect("asset_double_clicked", _on_asset_double_clicked)


func _on_asset_double_clicked(asset_id: String) -> void:
	if session == null: return
	var asset: Dictionary = session.asset_registry.get_asset(asset_id)
	var part_id := str((asset.get("metadata", {}) as Dictionary).get("character_part_id", ""))
	if not part_id.is_empty(): _equip_part(part_id)


func _selected_slot_id() -> String:
	return str(slot_select.get_item_metadata(slot_select.selected)) if slot_select != null and slot_select.selected >= 0 else ""


func _selected_part_id() -> String:
	var items := part_list.get_selected_items() if part_list != null else PackedInt32Array()
	return str(part_list.get_item_metadata(items[0])) if not items.is_empty() else ""


func _selected_layer_id() -> String:
	var items := layer_list.get_selected_items() if layer_list != null else PackedInt32Array()
	return str(layer_list.get_item_metadata(items[0])) if not items.is_empty() else ""


func _select_part(part_id: String) -> void:
	if part_id.is_empty(): return
	for index in part_list.item_count:
		if str(part_list.get_item_metadata(index)) == part_id: part_list.select(index); return


func _select_layer(part_id: String) -> void:
	if part_id.is_empty() or layer_list == null: return
	for index in layer_list.item_count:
		if str(layer_list.get_item_metadata(index)) == part_id:
			layer_list.select(index)
			return


func _refresh_layer_editor() -> void:
	var part_id := _selected_layer_id()
	var has_layer := model != null and not part_id.is_empty()
	_setting_layer_controls = true
	if has_layer:
		var values: Dictionary = model.get_layer_transform_values(part_id)
		pos_x.value = float(values.get("pos_x", 0.0))
		pos_y.value = float(values.get("pos_y", 0.0))
		scale_x.value = float(values.get("scale_x", 1.0))
		scale_y.value = float(values.get("scale_y", 1.0))
		rotation_input.value = float(values.get("rotation_deg", 0.0))
		pivot_x.value = float(values.get("pivot_x", 0.5))
		pivot_y.value = float(values.get("pivot_y", 0.5))
		opacity.value = float(values.get("opacity", 1.0))
		var tint_values: Array = values.get("tint", [1.0, 1.0, 1.0, 1.0])
		tint.color = Color(float(tint_values[0]), float(tint_values[1]), float(tint_values[2]), float(tint_values[3]))
		var state: Dictionary = model.get_layer_state(part_id)
		layer_visibility.text = "Show" if not bool(state.get("visible", true)) else "Hide"
		layer_lock.text = "Unlock" if bool(state.get("locked", false)) else "Lock"
		layer_solo.text = "Unsolo" if str(model.assembly.metadata.get("solo_part_id", "")) == part_id else "Solo"
	_setting_layer_controls = false
	var controls: Array = [layer_move_up, layer_move_down, layer_visibility, layer_lock, layer_solo, layer_duplicate, layer_replace, layer_delete, pos_x, pos_y, scale_x, scale_y, rotation_input, pivot_x, pivot_y, opacity, tint]
	for control in controls: _set_control_enabled(control, has_layer)


func _refresh_selection_state() -> void:
	var part_id := _selected_part_id()
	equip_button.disabled = part_id.is_empty()
	unequip_button.disabled = part_id.is_empty() or model == null or part_id not in model.assembly.get_equipped_part_ids()
	undo_button.disabled = model == null or (not CommandService.can_undo() if session != null and CommandService != null else not model.can_undo())
	redo_button.disabled = model == null or (not CommandService.can_redo() if session != null and CommandService != null else not model.can_redo())
	if session != null and CommandService != null:
		var undo_label := CommandService.get_undo_description()
		var redo_label := CommandService.get_redo_description()
		undo_button.tooltip_text = "Undo " + undo_label if not undo_label.is_empty() else "Nothing to undo"
		redo_button.tooltip_text = "Redo " + redo_label if not redo_label.is_empty() else "Nothing to redo"
		history_label.text = "Next undo: " + undo_label if not undo_label.is_empty() else ("Next redo: " + redo_label if not redo_label.is_empty() else "No document changes in history.")
	else:
		history_label.text = "No document changes in history."


func _on_document_history_changed(_can_undo: bool, _can_redo: bool) -> void:
	_refresh_selection_state()


func _set_character_name(value: String) -> void:
	_setting_name = true
	name_input.text = value
	_setting_name = false


func _set_editing_enabled(enabled: bool) -> void:
	name_input.editable = enabled
	search_input.editable = enabled
	for button in [apply_button, slot_select, import_button, import_folder_button, repair_missing_button, equip_button, unequip_button, undo_button, redo_button, apply_template_button, apply_canvas_button, layer_move_up, layer_move_down, layer_visibility, layer_lock, layer_solo, layer_duplicate, layer_replace, layer_delete]: button.disabled = not enabled
	for input in [template_select, canvas_width, canvas_height, pixel_scale, pos_x, pos_y, scale_x, scale_y, rotation_input, pivot_x, pivot_y, opacity, tint]: _set_control_enabled(input, enabled)
	part_list.mouse_filter = Control.MOUSE_FILTER_STOP if enabled else Control.MOUSE_FILTER_IGNORE
	part_list.focus_mode = Control.FOCUS_ALL if enabled else Control.FOCUS_NONE
	layer_list.mouse_filter = Control.MOUSE_FILTER_STOP if enabled else Control.MOUSE_FILTER_IGNORE
	layer_list.focus_mode = Control.FOCUS_ALL if enabled else Control.FOCUS_NONE


func _set_control_enabled(control: Control, enabled: bool) -> void:
	if control is SpinBox:
		(control as SpinBox).editable = enabled
	else:
		control.set("disabled", not enabled)


func _on_project_closed() -> void:
	if session != null: session.queue_free()
	session = null
	model = null
	_set_editing_enabled(false)
	slot_select.clear()
	part_list.clear()
	layer_list.clear()
	preview.set_layers([])
	layer_summary.text = "0 layers equipped · imported artwork will appear here"
	_bind_asset_browser()
	_refresh_status("Project closed.")


func _refresh_status(message: String) -> void:
	var lower := message.to_lower()
	var is_error := "failed" in lower or "could not" in lower or "invalid" in lower or "cannot" in lower or "missing" in lower
	var is_success := "ready" in lower or "equipped" in lower or "saved" in lower or "imported" in lower
	var token := "error" if is_error else ("success" if is_success else "blue")
	status_label.text = ("× " if is_error else ("✓ " if is_success else "i ")) + message
	if ThemeService != null: status_label.add_theme_color_override("font_color", ThemeService.get_color_token(token))


func _failure(message: String) -> Dictionary:
	return {"success": false, "errors": [message], "repair_actions": []}
