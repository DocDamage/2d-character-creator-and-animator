# TextureAtlasPacker -- Deterministic shelf packing and optional edge extrusion for Image frames.
class_name TextureAtlasPacker
extends RefCounted


func pack(frames: Array, max_size: Vector2i = Vector2i(2048, 2048), padding: int = 1, extrusion: int = 0) -> Dictionary:
	var ordered := frames.duplicate(true)
	ordered.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var size_a := _frame_size(a)
		var size_b := _frame_size(b)
		return str(a.get("id", "")) < str(b.get("id", "")) if size_a.y == size_b.y else size_a.y > size_b.y
	)
	var pages: Array = []
	var page := _new_page(max_size)
	for frame in ordered:
		var source_size := _frame_size(frame)
		var total_size := source_size + Vector2i.ONE * (padding + extrusion) * 2
		if total_size.x > max_size.x or total_size.y > max_size.y:
			return {"success": false, "error": "frame exceeds atlas bounds", "frame_id": frame.get("id", "")}
		if page["cursor_x"] + total_size.x > max_size.x:
			page["cursor_x"] = 0
			page["cursor_y"] += page["row_height"]
			page["row_height"] = 0
		if page["cursor_y"] + total_size.y > max_size.y:
			pages.append(page)
			page = _new_page(max_size)
		var outer := Rect2i(Vector2i(page["cursor_x"], page["cursor_y"]), total_size)
		var content_position := outer.position + Vector2i.ONE * (padding + extrusion)
		(page["placements"] as Array).append({
			"id": str(frame.get("id", "")),
			"rect": [content_position.x, content_position.y, source_size.x, source_size.y],
			"outer_rect": [outer.position.x, outer.position.y, outer.size.x, outer.size.y],
			"source_rect": frame.get("source_rect", [0, 0, source_size.x, source_size.y]),
			"frame": frame,
		})
		page["cursor_x"] = int(page["cursor_x"]) + total_size.x
		page["row_height"] = maxi(int(page["row_height"]), total_size.y)
	pages.append(page)
	return {"success": true, "pages": pages, "padding": padding, "extrusion": extrusion}


func render_pages(layout: Dictionary) -> Array:
	var images: Array = []
	if not bool(layout.get("success", false)):
		return images
	for page in layout.get("pages", []) as Array:
		var image := Image.create_empty(page["size"].x, page["size"].y, false, Image.FORMAT_RGBA8)
		for placement in page.get("placements", []) as Array:
			var frame: Dictionary = placement.get("frame", {})
			var source: Image = frame.get("image")
			if source == null:
				continue
			var rect_data: Array = placement.get("rect", [])
			var target := Rect2i(Vector2i(int(rect_data[0]), int(rect_data[1])), Vector2i(int(rect_data[2]), int(rect_data[3])))
			image.blit_rect(source, Rect2i(Vector2i.ZERO, source.get_size()), target.position)
			_extrude(image, target, int(layout.get("extrusion", 0)))
		images.append(image)
	return images


func _new_page(size: Vector2i) -> Dictionary:
	return {"size": size, "cursor_x": 0, "cursor_y": 0, "row_height": 0, "placements": []}


func _frame_size(frame: Dictionary) -> Vector2i:
	var image: Image = frame.get("image")
	if image != null:
		return image.get_size()
	var size = frame.get("size", Vector2i.ZERO)
	return size if size is Vector2i else Vector2i(int((size as Array)[0]), int((size as Array)[1]))


func _extrude(image: Image, rect: Rect2i, amount: int) -> void:
	for distance in range(1, amount + 1):
		for x in range(rect.position.x, rect.end.x):
			image.set_pixel(x, rect.position.y - distance, image.get_pixel(x, rect.position.y))
			image.set_pixel(x, rect.end.y - 1 + distance, image.get_pixel(x, rect.end.y - 1))
		for y in range(rect.position.y, rect.end.y):
			image.set_pixel(rect.position.x - distance, y, image.get_pixel(rect.position.x, y))
			image.set_pixel(rect.end.x - 1 + distance, y, image.get_pixel(rect.end.x - 1, y))
