# CharacterRasterRenderer -- Deterministic CPU compositor shared by review
# packages.  It draws only registered imported image layers and their evaluated
# transforms; it never asks an image generator for content.
class_name CharacterRasterRenderer
extends RefCounted

var _image_cache: Dictionary = {}


func render_layers(layers: Array, canvas_settings: Dictionary, background_mode: String = "neutral") -> Image:
	var logical_width := clampi(int(canvas_settings.get("width", 512)), 16, 8192)
	var logical_height := clampi(int(canvas_settings.get("height", 512)), 16, 8192)
	var pixel_scale := clampf(float(canvas_settings.get("pixel_scale", 1.0)), 0.25, 16.0)
	var size := Vector2i(maxi(1, int(round(logical_width * pixel_scale))), maxi(1, int(round(logical_height * pixel_scale))))
	var output := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	_fill_background(output, background_mode)
	var center := Vector2(size) * 0.5
	for raw_layer in layers:
		var layer: Dictionary = raw_layer
		if not bool(layer.get("visible", true)) or bool(layer.get("missing", false)): continue
		var source := _load_image(str(layer.get("path", "")))
		if source == null or source.is_empty(): continue
		_draw_layer(output, source, layer.get("state", {}) as Dictionary, center, pixel_scale)
	return output


func _fill_background(image: Image, mode: String) -> void:
	match mode:
		"transparent": image.fill(Color(0.0, 0.0, 0.0, 0.0))
		"checkerboard":
			var light := Color("d5d9e2")
			var dark := Color("aeb5c4")
			var cell := 16
			for y in range(image.get_height()):
				for x in range(image.get_width()): image.set_pixel(x, y, light if ((x / cell) + (y / cell)) % 2 == 0 else dark)
		_: image.fill(Color("20242d"))


func _draw_layer(output: Image, source: Image, state: Dictionary, canvas_center: Vector2, pixel_scale: float) -> void:
	var position := _vector(state.get("position", [0.0, 0.0])) * pixel_scale
	var scale := _vector(state.get("scale", [1.0, 1.0]), Vector2.ONE) * pixel_scale
	if absf(scale.x) < 0.00001 or absf(scale.y) < 0.00001: return
	var pivot := _vector(state.get("pivot", [0.5, 0.5]), Vector2(0.5, 0.5))
	var tint_values: Array = state.get("tint", [1.0, 1.0, 1.0, 1.0])
	var tint := Color(float(tint_values[0]) if tint_values.size() > 0 else 1.0, float(tint_values[1]) if tint_values.size() > 1 else 1.0, float(tint_values[2]) if tint_values.size() > 2 else 1.0, float(tint_values[3]) if tint_values.size() > 3 else 1.0)
	tint.a *= clampf(float(state.get("opacity", 1.0)), 0.0, 1.0)
	if tint.a <= 0.0: return
	var rotation := deg_to_rad(float(state.get("rotation_degrees", 0.0)))
	var origin := canvas_center + position
	var texture_size := Vector2(source.get_width(), source.get_height())
	var local_corners := [Vector2(-pivot.x * texture_size.x, -pivot.y * texture_size.y), Vector2((1.0 - pivot.x) * texture_size.x, -pivot.y * texture_size.y), Vector2((1.0 - pivot.x) * texture_size.x, (1.0 - pivot.y) * texture_size.y), Vector2(-pivot.x * texture_size.x, (1.0 - pivot.y) * texture_size.y)]
	var bounds := Rect2(origin, Vector2.ZERO)
	for local_corner in local_corners: bounds = bounds.expand(origin + (local_corner * scale).rotated(rotation))
	var start_x := clampi(int(floor(bounds.position.x)), 0, output.get_width() - 1)
	var start_y := clampi(int(floor(bounds.position.y)), 0, output.get_height() - 1)
	var end_x := clampi(int(ceil(bounds.end.x)), 0, output.get_width())
	var end_y := clampi(int(ceil(bounds.end.y)), 0, output.get_height())
	for y in range(start_y, end_y):
		for x in range(start_x, end_x):
			var local := (Vector2(float(x) + 0.5, float(y) + 0.5) - origin).rotated(-rotation) / scale
			var sample := local + pivot * texture_size
			var sx := int(floor(sample.x))
			var sy := int(floor(sample.y))
			if sx < 0 or sy < 0 or sx >= source.get_width() or sy >= source.get_height(): continue
			var pixel := source.get_pixel(sx, sy)
			pixel = Color(pixel.r * tint.r, pixel.g * tint.g, pixel.b * tint.b, pixel.a * tint.a)
			if pixel.a <= 0.0: continue
			_blend_pixel(output, x, y, pixel)


func _blend_pixel(image: Image, x: int, y: int, source: Color) -> void:
	var destination := image.get_pixel(x, y)
	var out_alpha := source.a + destination.a * (1.0 - source.a)
	if out_alpha <= 0.000001:
		image.set_pixel(x, y, Color(0, 0, 0, 0))
		return
	var result := Color()
	result.r = (source.r * source.a + destination.r * destination.a * (1.0 - source.a)) / out_alpha
	result.g = (source.g * source.a + destination.g * destination.a * (1.0 - source.a)) / out_alpha
	result.b = (source.b * source.a + destination.b * destination.a * (1.0 - source.a)) / out_alpha
	result.a = out_alpha
	image.set_pixel(x, y, result)


func _load_image(path: String) -> Image:
	if path.is_empty() or not FileAccess.file_exists(path): return null
	if _image_cache.has(path): return (_image_cache[path] as Image).duplicate()
	var image := Image.load_from_file(path)
	if image == null or image.is_empty(): return null
	_image_cache[path] = image.duplicate()
	return image


func _vector(value: Variant, fallback: Vector2 = Vector2.ZERO) -> Vector2:
	if value is Vector2: return value as Vector2
	if value is Array and (value as Array).size() >= 2: return Vector2(float((value as Array)[0]), float((value as Array)[1]))
	return fallback
