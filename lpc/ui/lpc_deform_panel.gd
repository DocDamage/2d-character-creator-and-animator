# LpcDeformPanel -- Reachable strict per-frame warp workspace and verified export surface.
class_name LpcDeformPanel
extends Control

const ModelScript = preload("res://lpc/deformation/lpc_deformation_workspace_model.gd")

signal profile_saved(profile: Dictionary, manifest: Dictionary, project_path: String)

var _model = ModelScript.new()
var _layers: OptionButton
var _preview: TextureRect
var _status: Label
var _vertex: SpinBox
var _offset_x: SpinBox
var _offset_y: SpinBox


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build()
	if not _model.changed.is_connected(_on_changed): _model.changed.connect(_on_changed)


func bind_context(catalog: Dictionary, profile: Dictionary, manifest: Dictionary = {}, project_path: String = "") -> Dictionary:
	var result := _model.bind_context(catalog, profile, manifest, project_path)
	_refresh_layers()
	return result


func get_model():
	return _model


func _build() -> void:
	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 8)
	add_child(root)
	var title := Label.new()
	title.text = "DEFORM · STRICT FRAME WARP"
	title.add_theme_font_size_override("font_size", 20)
	root.add_child(title)
	var source_bar := HBoxContainer.new()
	source_bar.add_theme_constant_override("separation", 8)
	root.add_child(source_bar)
	_layers = OptionButton.new()
	_layers.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	source_bar.add_child(_layers)
	var load := Button.new()
	load.text = "Load frame"
	load.pressed.connect(_load_frame)
	source_bar.add_child(load)
	var grid := Button.new()
	grid.text = "Create grid"
	grid.pressed.connect(func(): _create_mesh("rectangular_grid"))
	source_bar.add_child(grid)
	var alpha := Button.new()
	alpha.text = "Create alpha mesh"
	alpha.pressed.connect(func(): _create_mesh("alpha_aware"))
	source_bar.add_child(alpha)
	var controls := HBoxContainer.new()
	controls.add_theme_constant_override("separation", 6)
	root.add_child(controls)
	_vertex = SpinBox.new()
	_vertex.min_value = 0
	_vertex.max_value = 4096
	_vertex.step = 1
	_vertex.tooltip_text = "Direct vertex index"
	controls.add_child(_vertex)
	_offset_x = SpinBox.new()
	_offset_x.min_value = -64
	_offset_x.max_value = 64
	_offset_x.step = 1
	_offset_x.tooltip_text = "Direct X offset"
	controls.add_child(_offset_x)
	_offset_y = SpinBox.new()
	_offset_y.min_value = -64
	_offset_y.max_value = 64
	_offset_y.step = 1
	_offset_y.tooltip_text = "Direct Y offset"
	controls.add_child(_offset_y)
	var move := Button.new()
	move.text = "Move vertex"
	move.pressed.connect(_move_vertex)
	controls.add_child(move)
	var pin := Button.new()
	pin.text = "Add pin"
	pin.pressed.connect(_add_pin)
	controls.add_child(pin)
	var lattice := Button.new()
	lattice.text = "2×2 lattice"
	lattice.pressed.connect(_add_lattice)
	controls.add_child(lattice)
	var drag := Button.new()
	drag.text = "Soft drag"
	drag.pressed.connect(_add_soft_drag)
	controls.add_child(drag)
	var reset := Button.new()
	reset.text = "Reset"
	reset.pressed.connect(func(): _status_from(_model.reset_deformation(), "Reset strict frame deformation."))
	controls.add_child(reset)
	var action_bar := HBoxContainer.new()
	action_bar.add_theme_constant_override("separation", 8)
	root.add_child(action_bar)
	var undo := Button.new()
	undo.text = "Undo"
	undo.pressed.connect(func(): if _model.undo(): _refresh_preview())
	action_bar.add_child(undo)
	var redo := Button.new()
	redo.text = "Redo"
	redo.pressed.connect(func(): if _model.redo(): _refresh_preview())
	action_bar.add_child(redo)
	var preview := Button.new()
	preview.text = "Interactive preview"
	preview.pressed.connect(_preview_interactive)
	action_bar.add_child(preview)
	var verify := Button.new()
	verify.text = "Verify strict bake"
	verify.pressed.connect(_verify)
	action_bar.add_child(verify)
	var export := Button.new()
	export.text = "Export strict PNG"
	export.pressed.connect(_export)
	action_bar.add_child(export)
	var save := Button.new()
	save.text = "Save"
	save.pressed.connect(_save)
	action_bar.add_child(save)
	_preview = TextureRect.new()
	_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_preview.custom_minimum_size = Vector2(320, 260)
	_preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(_preview)
	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.text = "Load a native source frame, create a frame-bound mesh, then verify an authoritative strict CPU bake before export."
	root.add_child(_status)


func _refresh_layers() -> void:
	if _layers == null: return
	var wanted := str(_layers.get_selected_metadata()) if _layers.item_count > 0 else ""
	_layers.clear()
	for raw in _model.profile.get("selections", []):
		if not raw is Dictionary: continue
		var selection: Dictionary = raw
		var index := _layers.item_count
		_layers.add_item(str(selection.get("asset_id", "")))
		_layers.set_item_metadata(index, str(selection.get("instance_id", "")))
		if str(selection.get("instance_id", "")) == wanted: _layers.select(index)
	if _layers.selected < 0 and _layers.item_count > 0: _layers.select(0)


func _load_frame() -> void:
	if _layers.selected < 0: return
	_status_from(_model.open_native_frame(str(_layers.get_selected_metadata())), "Loaded immutable native frame. Creating a mesh will not alter it.")


func _create_mesh(strategy: String) -> void:
	var result := _model.create_mesh(strategy, {"columns": 4, "rows": 4})
	_status_from(result, "Created %s strict frame mesh." % strategy)
	if bool(result.get("success", false)): _refresh_preview()


func _move_vertex() -> void:
	var result := _model.move_vertex(int(_vertex.value), Vector2(_offset_x.value, _offset_y.value))
	_status_from(result, "Applied direct vertex offset.")
	if bool(result.get("success", false)): _refresh_preview()


func _add_pin() -> void:
	var result := _model.add_pin(Vector2(32, 32), Vector2(2, 0), 24.0)
	_status_from(result, "Added named radial pin control.")
	if bool(result.get("success", false)): _refresh_preview()


func _add_lattice() -> void:
	var result := _model.set_lattice({"origin": [0, 0], "size": [64, 64], "columns": 2, "rows": 2, "offsets": {"1:0": [2, 0], "1:1": [2, 0]}})
	_status_from(result, "Applied bilinear lattice controls.")
	if bool(result.get("success", false)): _refresh_preview()


func _add_soft_drag() -> void:
	var result := _model.add_soft_drag(Vector2(32, 32), Vector2(34, 32), 18.0)
	_status_from(result, "Applied non-destructive soft drag.")
	if bool(result.get("success", false)): _refresh_preview()


func _preview_interactive() -> void:
	var result := _model.interactive_preview()
	_status_from(result, "Interactive preview is not an export claim; use Verify strict bake for the authoritative artifact.")
	_show_image(result)


func _verify() -> void:
	var directory := "user://lpc_exports/" + str(_model.profile.get("project_uuid", "character")) + "/strict_warp"
	var result := _model.verify(directory.path_join("verified_preview.png"))
	_status_from(result, "Verified strict CPU bake with deterministic hash and audit artifact.")
	_show_image(result)


func _export() -> void:
	var directory := "user://lpc_exports/" + str(_model.profile.get("project_uuid", "character")) + "/strict_warp"
	var result := _model.export_strict(directory)
	_status_from(result, "Exported verified strict PNG and manifest.")
	_show_image((result.get("bake", {}) as Dictionary))


func _save() -> void:
	var saved := _model.save()
	_status_from(saved, "Saved strict frame-mesh controls and bake cache.")
	if bool(saved.get("success", false)):
		profile_saved.emit(_model.profile.duplicate(true), _model.manifest.duplicate(true), _model.project_path)


func _refresh_preview() -> void:
	var result := _model.interactive_preview()
	if bool(result.get("success", false)): _show_image(result)


func _show_image(result: Dictionary) -> void:
	var image: Image = result.get("image", null)
	if image != null and not image.is_empty(): _preview.texture = ImageTexture.create_from_image(image)


func _status_from(result: Dictionary, success_message: String) -> void:
	if _status == null: return
	_status.text = success_message if bool(result.get("success", false)) else str(result.get("errors", ["Strict frame deformation failed."])[0])


func _on_changed(_description: String) -> void:
	_refresh_preview()
