# PoseThumbnailModel -- Produces deterministic raster previews from normalized pose transforms.
class_name PoseThumbnailModel
extends RefCounted


static func render_pose(pose: Variant, size: Vector2i = Vector2i(128, 96)) -> Dictionary:
	if pose == null or pose.bone_transforms.is_empty():
		return {"success": false, "message": "A pose with bone transforms is required."}
	var positions: Array[Vector2] = [Vector2.ZERO]
	for bone_id in pose.bone_transforms:
		positions.append(_position(pose.get_bone_transform(str(bone_id))))
	var image := Image.create(maxi(size.x, 1), maxi(size.y, 1), false, Image.FORMAT_RGBA8)
	image.fill(Color("20242d"))
	var min_point := positions[0]
	var max_point := positions[0]
	for point in positions:
		min_point = min_point.min(point)
		max_point = max_point.max(point)
	var span := max_point - min_point
	var scale: float = min((float(image.get_width()) - 20.0) / maxf(span.x, 1.0), (float(image.get_height()) - 20.0) / maxf(span.y, 1.0))
	var origin := _project(Vector2.ZERO, min_point, scale, image.get_size())
	_draw_dot(image, origin, Color("f5c16c"), 3)
	for index in range(1, positions.size()):
		var point := _project(positions[index], min_point, scale, image.get_size())
		_draw_line(image, origin, point, Color("7695bd"))
		_draw_dot(image, point, Color("d8e5ff"), 3)
	return {"success": true, "image": image, "texture": ImageTexture.create_from_image(image), "bone_count": positions.size() - 1, "message": "Rendered %d pose transforms." % (positions.size() - 1)}


static func _position(transform: Dictionary) -> Vector2:
	var value: Variant = transform.get("position", [0.0, 0.0])
	if value is Vector2:
		return value
	if value is Array and value.size() >= 2:
		return Vector2(float(value[0]), float(value[1]))
	return Vector2.ZERO


static func _project(point: Vector2, min_point: Vector2, scale: float, size: Vector2i) -> Vector2i:
	return Vector2i(roundi(10.0 + (point.x - min_point.x) * scale), roundi(float(size.y) - 10.0 - (point.y - min_point.y) * scale))


static func _draw_dot(image: Image, center: Vector2i, color: Color, radius: int) -> void:
	for y in range(center.y - radius, center.y + radius + 1):
		for x in range(center.x - radius, center.x + radius + 1):
			if x >= 0 and y >= 0 and x < image.get_width() and y < image.get_height() and Vector2(x - center.x, y - center.y).length_squared() <= radius * radius:
				image.set_pixel(x, y, color)


static func _draw_line(image: Image, start: Vector2i, end: Vector2i, color: Color) -> void:
	var point := start
	var delta := Vector2i(absi(end.x - start.x), -absi(end.y - start.y))
	var step := Vector2i(1 if start.x < end.x else -1, 1 if start.y < end.y else -1)
	var error := delta.x + delta.y
	while true:
		if point.x >= 0 and point.y >= 0 and point.x < image.get_width() and point.y < image.get_height():
			image.set_pixel(point.x, point.y, color)
		if point == end:
			break
		var doubled := error * 2
		if doubled >= delta.y:
			error += delta.y
			point.x += step.x
		if doubled <= delta.x:
			error += delta.x
			point.y += step.y
