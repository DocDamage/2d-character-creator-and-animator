# CharacterLayerPreview -- Composites exact imported artwork with persisted layer transforms.
class_name CharacterLayerPreview
extends Control

signal files_dropped(paths: Array)
signal layer_selected(part_id: String)
signal layer_dragged(part_id: String, canvas_delta: Vector2)
signal view_changed(zoom: float, pan: Vector2)
signal gameplay_overlay_selected(kind: String, overlay_id: String, data: Dictionary)

var _layers: Array = []
var _textures: Array[Texture2D] = []
var _textures_by_part: Dictionary = {}
var _textures_by_path: Dictionary = {}
var _zoom := 1.0
var _pan := Vector2.ZERO
var _show_pixel_grid := false
var _canvas_size := Vector2(512.0, 512.0)
var _pixel_scale := 1.0
var _rig: Dictionary = {}
var _show_rig := false
var _action_points: Array = []
var _hitboxes: Array = []
var _hurtboxes: Array = []
var _onion_past_layers: Array = []
var _onion_future_layers: Array = []
var _selected_part_id := ""
var _dragged_part_id := ""
var _drag_start_position := Vector2.ZERO
var _last_mouse_position := Vector2.ZERO
var _is_panning := false


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
	_textures_by_path.clear()
	for raw_layer in _layers:
		var layer: Dictionary = raw_layer
		var path := str(layer.get("path", ""))
		var part_id := str(layer.get("part_id", ""))
		var texture := _texture_for_path(path)
		if texture != null:
			_textures.append(texture)
			_textures_by_part[part_id] = texture
	queue_redraw()


func set_rig(rig: Dictionary, show_overlay: bool = true) -> void:
	_rig = rig.duplicate(true)
	_show_rig = show_overlay and not _rig.is_empty()
	queue_redraw()


func set_rig_overlay_visible(visible: bool) -> void:
	_show_rig = visible and not _rig.is_empty()
	queue_redraw()


func set_gameplay_overlays(action_points: Array, hitboxes: Array, hurtboxes: Array) -> void:
	_action_points = action_points.duplicate(true)
	_hitboxes = hitboxes.duplicate(true)
	_hurtboxes = hurtboxes.duplicate(true)
	queue_redraw()


func set_onion_layers(past_layers: Array, future_layers: Array) -> void:
	_onion_past_layers = past_layers.duplicate(true)
	_onion_future_layers = future_layers.duplicate(true)
	queue_redraw()


func set_selected_layer(part_id: String) -> void:
	if _selected_part_id == part_id: return
	_selected_part_id = part_id
	queue_redraw()


func get_selected_layer() -> String:
	return _selected_part_id


func set_pixel_grid(enabled: bool) -> void:
	_show_pixel_grid = enabled
	queue_redraw()


func zoom_in() -> void:
	_zoom = minf(_zoom * 1.25, 8.0)
	view_changed.emit(_zoom, _pan)
	queue_redraw()


func zoom_out() -> void:
	_zoom = maxf(_zoom / 1.25, 0.25)
	view_changed.emit(_zoom, _pan)
	queue_redraw()


func reset_view() -> void:
	_zoom = 1.0
	_pan = Vector2.ZERO
	view_changed.emit(_zoom, _pan)
	queue_redraw()


func get_loaded_layer_count() -> int:
	return _textures.size()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.pressed:
			if event.button_index == MOUSE_BUTTON_WHEEL_UP:
				zoom_in()
				accept_event()
			elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				zoom_out()
				accept_event()
			elif event.button_index == MOUSE_BUTTON_MIDDLE:
				_is_panning = true
				_last_mouse_position = event.position
				accept_event()
			elif event.button_index == MOUSE_BUTTON_LEFT:
				var overlay_hit := _pick_gameplay_overlay(event.position)
				if not overlay_hit.is_empty():
					gameplay_overlay_selected.emit(str(overlay_hit.get("kind", "")), str(overlay_hit.get("overlay_id", "")), overlay_hit.get("data", {}) as Dictionary)
					accept_event()
					return
				var hit_id := _pick_layer(event.position)
				if not hit_id.is_empty():
					_selected_part_id = hit_id
					_dragged_part_id = hit_id
					_drag_start_position = event.position
					layer_selected.emit(hit_id)
					queue_redraw()
					accept_event()
		else:
			if event.button_index == MOUSE_BUTTON_MIDDLE:
				_is_panning = false
			elif event.button_index == MOUSE_BUTTON_LEFT:
				_dragged_part_id = ""
	elif event is InputEventMouseMotion:
		if _is_panning:
			_pan += event.position - _last_mouse_position
			_last_mouse_position = event.position
			view_changed.emit(_zoom, _pan)
			queue_redraw()
			accept_event()
		elif not _dragged_part_id.is_empty() and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			var canvas_delta: Vector2 = (event.position - _drag_start_position) / _get_view_scale()
			if canvas_delta.length_squared() > 0.0:
				_drag_start_position = event.position
				layer_dragged.emit(_dragged_part_id, canvas_delta)
				accept_event()


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
	var view_scale := _get_view_scale()
	var canvas_rect := _get_canvas_rect(view_scale)
	var border := line
	border.a = 0.75
	draw_rect(canvas_rect, border, false, 1.0)
	_draw_onion_layers(_onion_past_layers, canvas_rect, view_scale, Color(1.0, 0.32, 0.38, 0.24))
	_draw_onion_layers(_onion_future_layers, canvas_rect, view_scale, Color(0.25, 0.55, 1.0, 0.24))
	for raw_layer in _layers:
		var layer: Dictionary = raw_layer
		if not bool(layer.get("visible", true)): continue
		var part_id := str(layer.get("part_id", ""))
		var texture: Texture2D = _textures_by_part.get(part_id, null)
		if texture == null:
			if bool(layer.get("missing", false)): _draw_missing_layer_marker(layer, canvas_rect)
			continue
		_draw_layer(texture, layer, canvas_rect, view_scale)
		if str(layer.get("part_id", "")) == _selected_part_id:
			_draw_layer_selection(texture, layer, canvas_rect, view_scale)
	if _show_rig: _draw_rig_overlay(canvas_rect, view_scale)
	_draw_gameplay_overlays(canvas_rect, view_scale)
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


func _draw_onion_layers(layers: Array, canvas_rect: Rect2, view_scale: float, ghost_tint: Color) -> void:
	for raw_layer in layers:
		var layer: Dictionary = raw_layer
		if not bool(layer.get("visible", true)): continue
		var texture: Texture2D = _texture_for_path(str(layer.get("path", "")))
		if texture == null: continue
		var ghost: Dictionary = layer.duplicate(true)
		var state: Dictionary = ghost.get("state", {}).duplicate(true)
		state["tint"] = [ghost_tint.r, ghost_tint.g, ghost_tint.b, ghost_tint.a]
		state["opacity"] = ghost_tint.a
		ghost["state"] = state
		_draw_layer(texture, ghost, canvas_rect, view_scale)


func _draw_layer_selection(texture: Texture2D, layer: Dictionary, canvas_rect: Rect2, view_scale: float) -> void:
	var state: Dictionary = layer.get("state", {})
	var position := _vector_from_values(state.get("position", [0.0, 0.0]), Vector2.ZERO)
	var scale_values := _vector_from_values(state.get("scale", [1.0, 1.0]), Vector2.ONE)
	var pivot := _vector_from_values(state.get("pivot", [0.5, 0.5]), Vector2(0.5, 0.5))
	var texture_size := Vector2(texture.get_width(), texture.get_height())
	var pivot_pixels := pivot * texture_size
	var origin := canvas_rect.get_center() + position * view_scale
	var layer_scale := scale_values * view_scale
	var angle := deg_to_rad(float(state.get("rotation_degrees", 0.0)))
	var corners := PackedVector2Array()
	for local_corner in [Vector2(-pivot_pixels.x, -pivot_pixels.y), Vector2(texture_size.x - pivot_pixels.x, -pivot_pixels.y), Vector2(texture_size.x - pivot_pixels.x, texture_size.y - pivot_pixels.y), Vector2(-pivot_pixels.x, texture_size.y - pivot_pixels.y)]:
		corners.append(origin + (local_corner * layer_scale).rotated(angle))
	corners.append(corners[0])
	var color := _theme_color("blue", Color("5ebcff"))
	color.a = 0.95
	draw_polyline(corners, color, 2.0)
	draw_circle(origin, 4.0, color)


func _draw_rig_overlay(canvas_rect: Rect2, view_scale: float) -> void:
	var bones: Dictionary = _rig.get("bones", {})
	for bone_id in bones:
		var bone: Dictionary = bones[bone_id]
		if not bool(bone.get("visible", true)): continue
		var transform := _get_rig_bone_transform(str(bone_id), bones)
		var origin: Vector2 = canvas_rect.get_center() + transform.origin * view_scale
		var end := origin + Vector2(float(bone.get("length", 50.0)) * view_scale, 0.0).rotated(transform.get_rotation())
		var color: Color = bone.get("color", Color("33b2ff")) as Color
		color.a = 0.9
		draw_line(origin, end, color, 3.0)
		draw_circle(origin, 4.0, color)


func _draw_gameplay_overlays(canvas_rect: Rect2, view_scale: float) -> void:
	var action_color := Color("ffd166")
	for raw_point in _action_points:
		var point: Dictionary = raw_point
		var center := _overlay_center(point, canvas_rect, view_scale)
		draw_line(center - Vector2(8, 0), center + Vector2(8, 0), action_color, 2.0)
		draw_line(center - Vector2(0, 8), center + Vector2(0, 8), action_color, 2.0)
		draw_circle(center, 4.0, action_color, false, 1.5)
	for raw_shape in _hitboxes:
		_draw_collision_overlay(raw_shape as Dictionary, canvas_rect, view_scale, Color("ff5d5d"))
	for raw_shape in _hurtboxes:
		_draw_collision_overlay(raw_shape as Dictionary, canvas_rect, view_scale, Color("5ebcff"))


func _draw_collision_overlay(shape: Dictionary, canvas_rect: Rect2, view_scale: float, color: Color) -> void:
	if not bool(shape.get("enabled", true)): return
	var center := _overlay_center(shape, canvas_rect, view_scale)
	var shape_type := int(shape.get("shape_type", 0))
	if shape_type == 1:
		draw_circle(center, maxf(1.0, float(shape.get("radius", 8.0)) * view_scale), color, false, 2.0)
		return
	var size := _vector_from_values(shape.get("size", [16.0, 16.0]), Vector2(16.0, 16.0)) * view_scale
	var rect := Rect2(center - size * 0.5, size)
	draw_rect(rect, color, false, 2.0)


func _get_rig_bone_transform(bone_id: String, bones: Dictionary) -> Transform2D:
	if not bones.has(bone_id): return Transform2D.IDENTITY
	var bone: Dictionary = bones[bone_id]
	var local := Transform2D(float(bone.get("local_rotation", 0.0)), bone.get("local_scale", Vector2.ONE) as Vector2, 0.0, bone.get("local_position", Vector2.ZERO) as Vector2)
	var parent_id := str(bone.get("parent_id", ""))
	return _get_rig_bone_transform(parent_id, bones) * local if not parent_id.is_empty() and bones.has(parent_id) else local


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


func _get_view_scale() -> float:
	var fit := minf((size.x - 48.0) / _canvas_size.x, (size.y - 48.0) / _canvas_size.y)
	return maxf(0.01, fit * _zoom * _pixel_scale)


func _get_canvas_rect(view_scale: float = -1.0) -> Rect2:
	var scale := view_scale if view_scale > 0.0 else _get_view_scale()
	var draw_size := _canvas_size * scale
	return Rect2((size - draw_size) * 0.5 + _pan, draw_size)


func _pick_layer(view_position: Vector2) -> String:
	var scale := _get_view_scale()
	var canvas_rect := _get_canvas_rect(scale)
	for index in range(_layers.size() - 1, -1, -1):
		var layer: Dictionary = _layers[index]
		if not bool(layer.get("visible", true)) or bool(layer.get("missing", false)): continue
		var part_id := str(layer.get("part_id", ""))
		var texture: Texture2D = _textures_by_part.get(part_id, null)
		if texture == null: continue
		var state: Dictionary = layer.get("state", {})
		var origin := canvas_rect.get_center() + _vector_from_values(state.get("position", [0.0, 0.0]), Vector2.ZERO) * scale
		var layer_scale := _vector_from_values(state.get("scale", [1.0, 1.0]), Vector2.ONE) * scale
		if absf(layer_scale.x) < 0.001 or absf(layer_scale.y) < 0.001: continue
		var local := (view_position - origin).rotated(-deg_to_rad(float(state.get("rotation_degrees", 0.0)))) / layer_scale
		var texture_size := Vector2(texture.get_width(), texture.get_height())
		var pivot := _vector_from_values(state.get("pivot", [0.5, 0.5]), Vector2(0.5, 0.5))
		if Rect2(-pivot * texture_size, texture_size).has_point(local): return part_id
	return ""


func _pick_gameplay_overlay(view_position: Vector2) -> Dictionary:
	var canvas_rect := _get_canvas_rect()
	var view_scale := _get_view_scale()
	# Preserve draw priority: hurtboxes and hitboxes are visually above the
	# action-point cross, and later overlays win within a family.
	for index in range(_hurtboxes.size() - 1, -1, -1):
		var hurt: Dictionary = _hurtboxes[index] as Dictionary
		if _overlay_contains(hurt, view_position, canvas_rect, view_scale):
			return {"kind": "hurtbox", "overlay_id": _overlay_id(hurt, "hurtbox"), "data": hurt.duplicate(true)}
	for index in range(_hitboxes.size() - 1, -1, -1):
		var hit: Dictionary = _hitboxes[index] as Dictionary
		if _overlay_contains(hit, view_position, canvas_rect, view_scale):
			return {"kind": "hitbox", "overlay_id": _overlay_id(hit, "hitbox"), "data": hit.duplicate(true)}
	for index in range(_action_points.size() - 1, -1, -1):
		var point: Dictionary = _action_points[index] as Dictionary
		if _overlay_center(point, canvas_rect, view_scale).distance_to(view_position) <= 10.0:
			return {"kind": "action_point", "overlay_id": _overlay_id(point, "action_point"), "data": point.duplicate(true)}
	return {}


func _overlay_contains(shape: Dictionary, view_position: Vector2, canvas_rect: Rect2, view_scale: float) -> bool:
	if not bool(shape.get("enabled", true)): return false
	var center := _overlay_center(shape, canvas_rect, view_scale)
	if int(shape.get("shape_type", 0)) == 1:
		return center.distance_to(view_position) <= maxf(1.0, float(shape.get("radius", 8.0)) * view_scale)
	var shape_size := _vector_from_values(shape.get("size", [16.0, 16.0]), Vector2(16.0, 16.0)) * view_scale
	return Rect2(center - shape_size * 0.5, shape_size).has_point(view_position)


func _overlay_center(data: Dictionary, canvas_rect: Rect2, view_scale: float) -> Vector2:
	var local := _vector_from_values(data.get("local_position", data.get("position", [0.0, 0.0])), Vector2.ZERO)
	return canvas_rect.get_center() + (_overlay_target_position(str(data.get("object_id", ""))) + local) * view_scale


func _overlay_target_position(object_id: String) -> Vector2:
	if object_id.is_empty(): return Vector2.ZERO
	for raw_layer in _layers:
		var layer: Dictionary = raw_layer
		if str(layer.get("part_id", "")) == object_id:
			return _vector_from_values((layer.get("state", {}) as Dictionary).get("position", [0.0, 0.0]), Vector2.ZERO)
	var bones: Dictionary = _rig.get("bones", {})
	if bones.has(object_id): return _get_rig_bone_transform(object_id, bones).origin
	return Vector2.ZERO


func _overlay_id(data: Dictionary, fallback: String) -> String:
	var identifier := str(data.get("action_point_id", data.get("shape_id", data.get("track_id", fallback))))
	return identifier if not identifier.is_empty() else fallback


func _vector_from_values(value: Variant, fallback: Vector2) -> Vector2:
	if value is Vector2: return value as Vector2
	if value is Array:
		var values: Array = value
		if values.size() >= 2: return Vector2(float(values[0]), float(values[1]))
	return fallback


func _texture_for_path(path: String) -> Texture2D:
	if path.is_empty() or not FileAccess.file_exists(path): return null
	if _textures_by_path.has(path): return _textures_by_path[path] as Texture2D
	var image := Image.load_from_file(path)
	if image == null or image.is_empty(): return null
	var texture := ImageTexture.create_from_image(image)
	_textures_by_path[path] = texture
	return texture


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
