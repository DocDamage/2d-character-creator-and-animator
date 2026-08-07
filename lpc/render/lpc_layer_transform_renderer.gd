# LpcLayerTransformRenderer -- Deterministic nearest-neighbor rigid transforms used by hybrid LPC evaluation.
class_name LpcLayerTransformRenderer
extends RefCounted


static func render(source: Image, canvas_size: Vector2i, transform: Dictionary = {}) -> Image:
	var output := Image.create(canvas_size.x, canvas_size.y, false, Image.FORMAT_RGBA8); output.fill(Color(0, 0, 0, 0))
	if source == null or source.is_empty(): return output
	var position := _vector(transform.get("position", transform.get("offset", [0, 0])))
	var scale := _vector(transform.get("scale", [1, 1]), Vector2.ONE)
	if is_zero_approx(scale.x) or is_zero_approx(scale.y): return output
	var pivot := _vector(transform.get("pivot", [source.get_width() * 0.5, source.get_height() * 0.5]), Vector2(source.get_width() * 0.5, source.get_height() * 0.5))
	var angle := deg_to_rad(float(transform.get("rotation_degrees", 0.0)))
	var cos_angle := cos(angle); var sin_angle := sin(angle)
	for y in range(canvas_size.y):
		for x in range(canvas_size.x):
			var destination := Vector2(x, y) - position - pivot
			var unrotated := Vector2(cos_angle * destination.x + sin_angle * destination.y, -sin_angle * destination.x + cos_angle * destination.y)
			var source_point := Vector2(unrotated.x / scale.x, unrotated.y / scale.y) + pivot
			var sx := floori(source_point.x); var sy := floori(source_point.y)
			if sx >= 0 and sy >= 0 and sx < source.get_width() and sy < source.get_height(): output.set_pixel(x, y, source.get_pixel(sx, sy))
	return output


static func _vector(value: Variant, fallback: Vector2 = Vector2.ZERO) -> Vector2:
	if value is Vector2: return value
	if value is Vector2i: return Vector2(value)
	if value is Array and (value as Array).size() >= 2: return Vector2(float((value as Array)[0]), float((value as Array)[1]))
	return fallback
