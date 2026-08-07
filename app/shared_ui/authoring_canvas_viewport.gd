# AuthoringCanvasViewport -- Project-bound 2D artwork canvas with selection, pan/zoom, and rig overlay.
class_name AuthoringCanvasViewport
extends VBoxContainer

const PreviewScript = preload("res://character/authoring/character_layer_preview.gd")
const TrackDefinitionScript = preload("res://animation/tracks/track_schema.gd")

signal status_changed(message: String)

var _session = null
var _selection = null
var _preview_controller = null
var _preview: Control = null
var _grid_button: Button = null
var _rig_button: Button = null
var _status_label: Label = null
var _show_grid := false
var _show_rig := true


func _ready() -> void:
	name = "AuthoringCanvasViewport"
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	_build_ui()
	_refresh()


func bind_session(session) -> void:
	if _session != null and is_instance_valid(_session) and _session.session_changed.is_connected(_on_session_changed):
		_session.session_changed.disconnect(_on_session_changed)
	_session = session
	if _session != null and is_instance_valid(_session) and not _session.session_changed.is_connected(_on_session_changed):
		_session.session_changed.connect(_on_session_changed)
	_refresh()


func bind_selection(selection) -> void:
	if _selection != null and is_instance_valid(_selection) and _selection.selection_changed.is_connected(_on_selection_changed):
		_selection.selection_changed.disconnect(_on_selection_changed)
	_selection = selection
	if _selection != null and is_instance_valid(_selection) and not _selection.selection_changed.is_connected(_on_selection_changed):
		_selection.selection_changed.connect(_on_selection_changed)
	_refresh_selection()


func bind_preview_controller(controller) -> void:
	if _preview_controller != null and is_instance_valid(_preview_controller) and _preview_controller.preview_evaluated.is_connected(_on_preview_evaluated):
		_preview_controller.preview_evaluated.disconnect(_on_preview_evaluated)
	_preview_controller = controller
	if _preview_controller != null and is_instance_valid(_preview_controller) and not _preview_controller.preview_evaluated.is_connected(_on_preview_evaluated):
		_preview_controller.preview_evaluated.connect(_on_preview_evaluated)
	if _preview_controller != null and is_instance_valid(_preview_controller): _on_preview_evaluated(_preview_controller.get_evaluated_frame())


func get_preview() -> Control:
	return _preview


func set_onion_layers(past_layers: Array, future_layers: Array) -> void:
	if _preview != null: _preview.call("set_onion_layers", past_layers, future_layers)


func _build_ui() -> void:
	var toolbar := HBoxContainer.new()
	toolbar.name = "ViewportToolbar"
	toolbar.add_theme_constant_override("separation", 6)
	add_child(toolbar)
	var zoom_out := Button.new()
	zoom_out.name = "ZoomOut"
	zoom_out.text = "−"
	zoom_out.tooltip_text = "Zoom out"
	zoom_out.pressed.connect(func(): _preview.call("zoom_out"))
	toolbar.add_child(zoom_out)
	var zoom_in := Button.new()
	zoom_in.name = "ZoomIn"
	zoom_in.text = "+"
	zoom_in.tooltip_text = "Zoom in"
	zoom_in.pressed.connect(func(): _preview.call("zoom_in"))
	toolbar.add_child(zoom_in)
	var reset := Button.new()
	reset.name = "ResetView"
	reset.text = "Frame"
	reset.tooltip_text = "Reset zoom and pan"
	reset.pressed.connect(func(): _preview.call("reset_view"))
	toolbar.add_child(reset)
	_grid_button = Button.new()
	_grid_button.name = "PixelGrid"
	_grid_button.text = "Pixel Grid"
	_grid_button.toggle_mode = true
	_grid_button.toggled.connect(_on_grid_toggled)
	toolbar.add_child(_grid_button)
	_rig_button = Button.new()
	_rig_button.name = "RigOverlay"
	_rig_button.text = "Rig Overlay"
	_rig_button.toggle_mode = true
	_rig_button.button_pressed = true
	_rig_button.toggled.connect(_on_rig_toggled)
	toolbar.add_child(_rig_button)
	var hint := Label.new()
	hint.name = "ViewportHint"
	hint.text = "Drag artwork to move · middle-drag to pan · wheel to zoom"
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	toolbar.add_child(hint)
	_preview = PreviewScript.new()
	_preview.name = "CharacterCanvas"
	# Keep the dock viable at compact desktop widths; the canvas grows with its tab.
	_preview.custom_minimum_size = Vector2(220, 180)
	_preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_preview.layer_selected.connect(_on_preview_layer_selected)
	_preview.layer_dragged.connect(_on_preview_layer_dragged)
	_preview.files_dropped.connect(_on_preview_files_dropped)
	_preview.gameplay_overlay_selected.connect(_on_gameplay_overlay_selected)
	add_child(_preview)
	_status_label = Label.new()
	_status_label.name = "ViewportStatus"
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.add_theme_font_size_override("font_size", 12)
	add_child(_status_label)


func _refresh() -> void:
	if _preview == null: return
	if _session == null or not is_instance_valid(_session):
		_preview.call("set_layers", [])
		_preview.call("set_rig", {}, false)
		_set_status("Open a project to place artwork and inspect its rig.")
		return
	_preview.call("set_canvas_settings", _session.get_canvas_settings())
	var preview_frame: Dictionary = _preview_controller.get_evaluated_frame() if _preview_controller != null and is_instance_valid(_preview_controller) else {}
	_preview.call("set_layers", preview_frame.get("layers", _session.get_preview_layers()))
	_preview.call("set_rig", preview_frame.get("rig_pose", _session.get_active_rig()), _show_rig)
	_preview.call("set_gameplay_overlays", preview_frame.get("action_points", []), preview_frame.get("hitboxes", []), preview_frame.get("hurtboxes", []))
	_preview.call("set_pixel_grid", _show_grid)
	_refresh_selection()
	var layers: Array = _session.get_preview_layers()
	var rig: Dictionary = _session.get_active_rig()
	_set_status("%d artwork layer%s · %s" % [layers.size(), "s" if layers.size() != 1 else "", str(rig.get("name", "No rig selected"))])


func _refresh_selection() -> void:
	if _preview == null: return
	var selected_layer := ""
	if _selection != null and is_instance_valid(_selection) and _selection.get_kind() == "layer":
		selected_layer = _selection.get_item_id()
	_preview.call("set_selected_layer", selected_layer)


func _on_session_changed(_description: String) -> void:
	_refresh()


func _on_preview_evaluated(frame: Dictionary) -> void:
	if _preview == null or _session == null or not is_instance_valid(_session): return
	if frame.is_empty():
		_preview.call("set_layers", _session.get_preview_layers())
		_preview.call("set_rig", _session.get_active_rig(), _show_rig)
		_preview.call("set_gameplay_overlays", [], [], [])
		return
	_preview.call("set_layers", frame.get("layers", []))
	_preview.call("set_rig", frame.get("rig_pose", {}), _show_rig)
	_preview.call("set_gameplay_overlays", frame.get("action_points", []), frame.get("hitboxes", []), frame.get("hurtboxes", []))


func _on_selection_changed(_kind: String, _item_id: String, _context: Dictionary) -> void:
	_refresh_selection()


func _on_grid_toggled(pressed: bool) -> void:
	_show_grid = pressed
	if _preview != null: _preview.call("set_pixel_grid", pressed)


func _on_rig_toggled(pressed: bool) -> void:
	_show_rig = pressed
	if _preview != null: _preview.call("set_rig_overlay_visible", pressed)


func _on_preview_layer_selected(part_id: String) -> void:
	if _selection != null and is_instance_valid(_selection):
		_selection.select("layer", part_id, {"source": "viewport"})


func _on_gameplay_overlay_selected(kind: String, overlay_id: String, data: Dictionary) -> void:
	if _selection != null and is_instance_valid(_selection):
		_selection.select(kind, overlay_id, {"source": "viewport", "overlay": data.duplicate(true)})
	_set_status("Selected " + kind.replace("_", " ") + ". Edit its keyframe in Timeline or Inspector.")


func _on_preview_layer_dragged(part_id: String, canvas_delta: Vector2) -> void:
	if _session == null or not is_instance_valid(_session) or _session.model == null: return
	var state: Dictionary = _session.model.get_layer_state(part_id)
	if _preview_controller != null and is_instance_valid(_preview_controller):
		for raw_layer in _preview_controller.get_evaluated_frame().get("layers", []):
			var layer: Dictionary = raw_layer
			if str(layer.get("part_id", "")) == part_id:
				state = (layer.get("state", {}) as Dictionary).duplicate(true)
				break
	if bool(state.get("locked", false)):
		_set_status("Unlock this layer before moving it.")
		return
	var values: Array = state.get("position", [0.0, 0.0])
	var current := Vector2(float(values[0]) if values.size() > 0 else 0.0, float(values[1]) if values.size() > 1 else 0.0)
	var next := current + canvas_delta
	if _preview_controller != null and is_instance_valid(_preview_controller):
		var report: Dictionary = _preview_controller.apply_property_edit(part_id, "layer:" + part_id + ".position", [next.x, next.y], Callable(_session.model, "set_layer_position").bind(part_id, next), TrackDefinitionScript.TrackType.TRANSFORM_POSITION)
		if report.get("success", false): _set_status("Auto-keyed layer position." if _preview_controller.is_auto_key_enabled() else "Moved layer. Ctrl+Z restores the prior position.")
	elif _session.model.set_layer_position(part_id, next):
		_set_status("Moved layer. Ctrl+Z restores the prior position.")


func _on_preview_files_dropped(paths: Array) -> void:
	if _session == null or not is_instance_valid(_session): return
	var files: Array = []
	var folders: Array = []
	for raw_path in paths:
		var path := str(raw_path)
		if DirAccess.dir_exists_absolute(path): folders.append(path)
		else: files.append(path)
	var imported: Array = []
	for folder in folders:
		var folder_report: Dictionary = _session.import_folder(folder)
		imported.append_array(folder_report.get("imported", []))
	if not files.is_empty():
		var file_report: Dictionary = _session.import_files_by_slot(files)
		imported.append_array(file_report.get("imported", []))
	if imported.is_empty():
		_set_status("Dropped artwork did not match a slot. Rename it for a slot or import it from Character Creator.")
	else:
		_set_status("Imported %d artwork layer%s from the canvas." % [imported.size(), "s" if imported.size() != 1 else ""])
		_refresh()


func _set_status(message: String) -> void:
	if _status_label != null: _status_label.text = message
	status_changed.emit(message)
