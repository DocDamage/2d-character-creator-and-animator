# CharacterLayerPreview -- Composites exact imported artwork with persisted layer transforms.
class_name CharacterLayerPreview
extends Control

signal files_dropped(paths: Array)

var _layers: Array = []
var _textures: Array[Texture2D] = []
var _textures_by_part: Dictionary = {}
var _zoom := 1.0
var _show_pixel_grid := false
var _canvas_size := Vector2(512.0, 512.0)
var _pixel_scale := 1.0


func _ready() -> void:
	resized.connect(queue_redraw)
	mouse_filter = Control.MOUSE_FILTER_STOP
	queue_redraw()


func set_canvas_settings(settings: Dictionary) -> void:
	_canvas_size = Vector2(clampf(float(settings.get("width", 512)), 16.0, 8192.0), clampf(float(settings.get("height", 512)), 16.0, 8192.0))
	_pixel_scale = clampf(float(settings.get("pixel_scale", 1.0)), 0.25, 16.0)
	queue_redraw()


func set_layers(layers: Array) -> void:
	_layers = layers.duplicate(true)
	_textures.clear()
	_textures_by_part.clear()
	for raw_layer in _layers:
		var layer: Dictionary = raw_layer
		var path := str(layer.get("path", ""))
		var part_id := str(layer.get("part_id", ""))
		if path.is_empty() or not FileAccess.file_exists(path): continue
		var image := Image.load_from_file(path)
		if image != null and not image.is_empty():
			var texture := ImageTexture.create_from_image(image)
			_textures.append(texture)
			_textures_by_part[part_id] = texture
	queue_redraw()


func set_pixel_grid(enabled: bool) -> void:
	_show_pixel_grid = enabled
	queue_redraw()


func zoom_in() -> void:
	_zoom = minf(_zoom * 1.25, 8.0)
	queue_redraw()


func zoom_out() -> void:
	_zoom = maxf(_zoom / 1.25, 0.25)
	queue_redraw()


func reset_view() -> void:
	_zoom = 1.0
	queue_redraw()


func get_loaded_layer_count() -> int:
	return _textures.size()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP: zoom_in(); accept_event()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN: zoom_out(); accept_event()


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return not _extract_image_paths(data).is_empty()


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	var paths := _extract_image_paths(data)
	if not paths.is_empty(): files_dropped.emit(paths)


func _draw() -> void:
	var background := _theme_color("bg_panel", Color("151820"))
	var line := _theme_color("border", Color("343b4a"))
	draw_rect(Rect2(Vector2.ZERO, size), background)
	_draw_checkerboard(line)
	if _layers.is_empty():
		_draw_empty_message()
		return
	var fit := minf((size.x - 48.0) / _canvas_size.x, (size.y - 48.0) / _canvas_size.y)
	var view_scale := maxf(0.01, fit * _zoom * _pixel_scale)
	var draw_size := _canvas_size * view_scale
	var canvas_rect := Rect2((size - draw_size) * 0.5, draw_size)
	var border := line
	border.a = 0.75
	draw_rect(canvas_rect, border, false, 1.0)
	for raw_layer in _layers:
		var layer: Dictionary = raw_layer
		if not bool(layer.get("visible", true)): continue
		var part_id := str(layer.get("part_id", ""))
		var texture: Texture2D = _textures_by_part.get(part_id, null)
		if texture == null:
			if bool(layer.get("missing", false)): _draw_missing_layer_marker(layer, canvas_rect)
			continue
		_draw_layer(texture, layer, canvas_rect, view_scale)
	if _show_pixel_grid and view_scale >= 4.0: _draw_grid(_canvas_size, view_scale, line, canvas_rect.position)


func _draw_layer(texture: Texture2D, layer: Dictionary, canvas_rect: Rect2, view_scale: float) -> void:
	var state: Dictionary = layer.get("state", {})
	var position: Array = state.get("position", [0.0, 0.0])
	var scale_values: Array = state.get("scale", [1.0, 1.0])
	var pivot: Array = state.get("pivot", [0.5, 0.5])
	var tint_values: Array = state.get("tint", [1.0, 1.0, 1.0, 1.0])
	var texture_size := Vector2(texture.get_width(), texture.get_height())
	var pivot_pixels := Vector2(float(pivot[0]) if pivot.size() > 0 else 0.5, float(pivot[1]) if pivot.size() > 1 else 0.5) * texture_size
	var offset := Vector2(float(position[0]) if position.size() > 0 else 0.0, float(position[1]) if position.size() > 1 else 0.0) * view_scale
	var origin := canvas_rect.get_center() + offset
	var layer_scale := Vector2(float(scale_values[0]) if scale_values.size() > 0 else 1.0, float(scale_values[1]) if scale_values.size() > 1 else 1.0) * view_scale
	var tint := Color(float(tint_values[0]) if tint_values.size() > 0 else 1.0, float(tint_values[1]) if tint_values.size() > 1 else 1.0, float(tint_values[2]) if tint_values.size() > 2 else 1.0, float(tint_values[3]) if tint_values.size() > 3 else 1.0)
	tint.a *= clampf(float(state.get("opacity", 1.0)), 0.0, 1.0)
	draw_set_transform(origin, deg_to_rad(float(state.get("rotation_degrees", 0.0))), layer_scale)
	draw_texture_rect(texture, Rect2(-pivot_pixels, texture_size), false, tint)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_checkerboard(line: Color) -> void:
	var cell := 18.0
	var alternate := line
	alternate.a = 0.16
	for y in int(ceil(size.y / cell)):
		for x in int(ceil(size.x / cell)):
			if (x + y) % 2 == 0: draw_rect(Rect2(x * cell, y * cell, cell, cell), alternate)


func _draw_empty_message() -> void:
	var font := ThemeDB.fallback_font
	var color := _theme_color("text_secondary", Color("8e98aa"))
	var title := "No artwork imported"
	var subtitle := "Drop PNG, WebP, or JPEG layers here, or import a folder."
	draw_string(font, Vector2(24, size.y * 0.5 - 8), title, HORIZONTAL_ALIGNMENT_CENTER, size.x - 48, 18, color)
	draw_string(font, Vector2(24, size.y * 0.5 + 20), subtitle, HORIZONTAL_ALIGNMENT_CENTER, size.x - 48, 13, color)


func _draw_missing_layer_marker(layer: Dictionary, canvas_rect: Rect2) -> void:
	var font := ThemeDB.fallback_font
	var color := _theme_color("error", Color("ff5d5d"))
	var message := "Missing: " + str(layer.get("name", "Layer"))
	draw_string(font, canvas_rect.position + Vector2(8, 22), message, HORIZONTAL_ALIGNMENT_LEFT, canvas_rect.size.x - 16, 13, color)


func _draw_grid(source_size: Vector2, scale: float, color: Color, start: Vector2) -> void:
	var draw_size := source_size * scale
	color.a = 0.35
	for x in int(source_size.x) + 1:
		draw_line(start + Vector2(x * scale, 0), start + Vector2(x * scale, draw_size.y), color)
	for y in int(source_size.y) + 1:
		draw_line(start + Vector2(0, y * scale), start + Vector2(draw_size.x, y * scale), color)


func _extract_image_paths(data: Variant) -> Array:
	var paths: Array = []
	if data is PackedStringArray or data is Array:
		for value in data:
			var path := str(value)
			if _is_supported_drop_path(path): paths.append(path)
	elif data is Dictionary:
		var dict: Dictionary = data
		for value in dict.get("files", []):
			var path := str(value)
			if _is_supported_drop_path(path): paths.append(path)
		var path := str(dict.get("path", ""))
		if _is_supported_drop_path(path) and path not in paths: paths.append(path)
	return paths


func _is_supported_drop_path(path: String) -> bool:
	if ImageImporter.is_supported_format(path):
		return true
	var absolute := ProjectSettings.globalize_path(path) if path.begins_with("res://") or path.begins_with("user://") else path
	return DirAccess.dir_exists_absolute(absolute)


func _theme_color(token: String, fallback: Color) -> Color:
	return ThemeService.get_color_token(token) if ThemeService != null else fallback
