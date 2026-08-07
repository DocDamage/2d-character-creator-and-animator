# LpcReferenceRenderer -- Deterministic CPU compositor used as the phase-0 reference path.
class_name LpcReferenceRenderer
extends RefCounted


static func render(layers: Array, canvas_size: Vector2i) -> Dictionary:
	if canvas_size.x <= 0 or canvas_size.y <= 0:
		return {"success": false, "errors": ["Reference render canvas must be positive."], "image": null}
	var ordered := layers.duplicate(true)
	ordered.sort_custom(func(a, b): return _sort_key(a) < _sort_key(b))
	var output := Image.create(canvas_size.x, canvas_size.y, false, Image.FORMAT_RGBA8)
	output.fill(Color(0, 0, 0, 0))
	var errors: Array[String] = []
	for raw_layer in ordered:
		if not raw_layer is Dictionary: errors.append("Reference render received an invalid layer."); continue
		var layer: Dictionary = raw_layer
		if not bool(layer.get("visible", true)): continue
		var source := _resolve_image(layer)
		if source == null or source.is_empty(): errors.append("Reference render could not load layer '%s'." % layer.get("layer_id", "")); continue
		var offset := _offset(layer.get("offset", layer.get("position", [0, 0])))
		_blit_over(output, source, offset)
	return {"success": errors.is_empty(), "errors": errors, "image": output, "output_hash": _image_hash(output), "layer_count": ordered.size()}


static func _blit_over(destination: Image, source: Image, offset: Vector2i) -> void:
	for y in range(source.get_height()):
		var destination_y := y + offset.y
		if destination_y < 0 or destination_y >= destination.get_height(): continue
		for x in range(source.get_width()):
			var destination_x := x + offset.x
			if destination_x < 0 or destination_x >= destination.get_width(): continue
			var foreground := source.get_pixel(x, y)
			if foreground.a8 == 0: continue
			var background := destination.get_pixel(destination_x, destination_y)
			var alpha := foreground.a + background.a * (1.0 - foreground.a)
			var result := foreground if alpha <= 0.000001 else Color((foreground.r * foreground.a + background.r * background.a * (1.0 - foreground.a)) / alpha, (foreground.g * foreground.a + background.g * background.a * (1.0 - foreground.a)) / alpha, (foreground.b * foreground.a + background.b * background.a * (1.0 - foreground.a)) / alpha, alpha)
			destination.set_pixel(destination_x, destination_y, result)


static func _resolve_image(layer: Dictionary) -> Image:
	if layer.get("image", null) is Image: return layer.image
	var path := str(layer.get("path", ""))
	return Image.load_from_file(path) if not path.is_empty() and FileAccess.file_exists(path) else null


static func _offset(value: Variant) -> Vector2i:
	if value is Vector2i: return value
	if value is Vector2: return Vector2i(roundi(value.x), roundi(value.y))
	if value is Array and (value as Array).size() >= 2: return Vector2i(int(value[0]), int(value[1]))
	return Vector2i.ZERO


static func _sort_key(value: Variant) -> String:
	if not value is Dictionary: return ""
	var layer: Dictionary = value
	return "%010d:%s" % [int(layer.get("z", layer.get("z_order", 0))), str(layer.get("layer_id", ""))]


static func _image_hash(image: Image) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(image.get_data())
	return context.finish().hex_encode()
