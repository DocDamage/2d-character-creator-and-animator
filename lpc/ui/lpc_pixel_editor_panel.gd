# LpcPixelEditorPanel -- Reachable pixel/cel workspace with integer-grid pointer editing and atomic history.
class_name LpcPixelEditorPanel
extends Control

const CanvasModelScript = preload("res://lpc/pixels/lpc_pixel_canvas_model.gd")
const ProjectStoreScript = preload("res://lpc/project/lpc_project_store.gd")

signal profile_saved(profile: Dictionary, manifest: Dictionary, project_path: String)

var _model = CanvasModelScript.new()
var _catalog: Dictionary = {}
var _profile: Dictionary = {}
var _manifest: Dictionary = {}
var _project_path := ""
var _layer: OptionButton
var _tool: OptionButton
var _color: ColorPickerButton
var _canvas: TextureRect
var _status: Label
var _painting := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build()


func bind_context(catalog: Dictionary, profile: Dictionary, manifest: Dictionary = {}, project_path: String = "") -> Dictionary:
	_catalog = catalog.duplicate(true); _profile = profile.duplicate(true); _manifest = manifest.duplicate(true); _project_path = project_path
	_refresh_layers()
	return {"success": not _catalog.is_empty(), "errors": [] if not _catalog.is_empty() else ["A locked LPC catalog is required."]}


func _build() -> void:
	var root := VBoxContainer.new(); root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); root.add_theme_constant_override("separation", 8); add_child(root)
	var title := Label.new(); title.text = "PIXEL & CEL EDITOR"; title.add_theme_font_size_override("font_size", 20); root.add_child(title)
	var toolbar := HBoxContainer.new(); toolbar.add_theme_constant_override("separation", 8); root.add_child(toolbar)
	_layer = OptionButton.new(); _layer.size_flags_horizontal = Control.SIZE_EXPAND_FILL; toolbar.add_child(_layer)
	var load := Button.new(); load.text = "Load native frame"; load.pressed.connect(_load_selected); toolbar.add_child(load)
	_tool = OptionButton.new()
	for item in ["Pencil", "Eraser", "Fill", "Select contiguous", "Select color"]:
		_tool.add_item(item)
	toolbar.add_child(_tool)
	_color = ColorPickerButton.new(); _color.color = Color.WHITE; toolbar.add_child(_color)
	var undo := Button.new(); undo.text = "Undo"; undo.pressed.connect(func(): if _model.undo(): _refresh_canvas()); toolbar.add_child(undo)
	var redo := Button.new(); redo.text = "Redo"; redo.pressed.connect(func(): if _model.redo(): _refresh_canvas()); toolbar.add_child(redo)
	var save := Button.new(); save.text = "Save cel"; save.pressed.connect(_save_cel); toolbar.add_child(save)
	_canvas = TextureRect.new(); _canvas.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; _canvas.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED; _canvas.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST; _canvas.custom_minimum_size = Vector2(360, 360); _canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL; _canvas.mouse_filter = Control.MOUSE_FILTER_STOP; _canvas.gui_input.connect(_canvas_input); root.add_child(_canvas)
	_status = Label.new(); _status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; root.add_child(_status)
	_set_status("Load a selected native frame to create a project-owned pixel edit or cel. One gesture is one undo step.")


func _refresh_layers() -> void:
	if _layer == null: return
	var wanted := str(_layer.get_selected_metadata()) if _layer.item_count > 0 else ""
	_layer.clear()
	for raw in _profile.get("selections", []):
		if not raw is Dictionary: continue
		var selection: Dictionary = raw; var index := _layer.item_count
		_layer.add_item(str(selection.get("asset_id", ""))); _layer.set_item_metadata(index, str(selection.get("instance_id", "")))
		if str(selection.get("instance_id", "")) == wanted: _layer.select(index)
	if _layer.selected < 0 and _layer.item_count > 0: _layer.select(0)


func _load_selected() -> void:
	if _layer.selected < 0: return
	var result := _model.open_native_frame(_catalog, _profile, str(_layer.get_selected_metadata()))
	_set_status("Loaded immutable source frame. Editing will create a project-owned derivative." if bool(result.get("success", false)) else str(result.get("errors", ["Could not load source frame."])[0]))
	_refresh_canvas()


func _canvas_input(event: InputEvent) -> void:
	if _model.image == null or _model.image.is_empty(): return
	var point := _image_point(event.position) if event is InputEventMouse else Vector2i(-1, -1)
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_apply_click(point)
		else:
			if _painting: _model.end_stroke(); _painting = false; _refresh_canvas()
	elif event is InputEventMouseMotion and _painting and (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
		_model.paint_pixel(point, _color.color, _tool.selected == 1); _refresh_canvas()


func _apply_click(point: Vector2i) -> void:
	match _tool.selected:
		1:
			_painting = _model.begin_stroke("Erase stroke"); _model.paint_pixel(point, _color.color, true)
		2:
			_model.fill(point, _color.color); _refresh_canvas()
		3:
			_set_status("Selected %d connected pixel(s)." % _model.select_contiguous(point)); _refresh_canvas()
		4:
			_set_status("Selected %d matching pixel(s)." % _model.select_noncontiguous(point)); _refresh_canvas()
		_:
			_painting = _model.begin_stroke("Pencil stroke"); _model.paint_pixel(point, _color.color)


func _save_cel() -> void:
	if _layer.selected < 0: return
	var committed := _model.commit_to_profile(_profile, {"target_id": str(_layer.get_selected_metadata()), "frame": 0, "kind": "pixel_edit"})
	if not bool(committed.get("success", false)): _set_status(str(committed.get("errors", ["Could not save cel."])[0])); return
	_profile = committed.profile
	var saved := ProjectStoreScript.save(_project_path, _manifest, _profile) if not _project_path.is_empty() and not _manifest.is_empty() else {"success": true, "manifest": _manifest}
	if bool(saved.get("success", false)):
		_manifest = saved.get("manifest", _manifest); profile_saved.emit(_profile.duplicate(true), _manifest.duplicate(true), _project_path); _set_status("Saved project-owned cel and derivative ancestry.")
	else: _set_status(str(saved.get("errors", ["Project save failed."])[0]))


func _refresh_canvas() -> void:
	if _canvas != null: _canvas.texture = ImageTexture.create_from_image(_model.image) if _model.image != null else null


func _image_point(position: Vector2) -> Vector2i:
	var size := _canvas.size; var width := maxf(1.0, size.x); var height := maxf(1.0, size.y)
	return Vector2i(clampi(int(floor(position.x / width * _model.image.get_width())), 0, _model.image.get_width() - 1), clampi(int(floor(position.y / height * _model.image.get_height())), 0, _model.image.get_height() - 1))


func _set_status(message: String) -> void:
	if _status != null: _status.text = message
