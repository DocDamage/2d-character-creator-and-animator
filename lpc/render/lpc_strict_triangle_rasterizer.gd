# LpcStrictTriangleRasterizer -- Deterministic nearest-sampled CPU triangle baker.
class_name LpcStrictTriangleRasterizer
extends RefCounted

const BAKER_VERSION := "1.0.0"


static func bake(source: Image, source_uvs: Array, destination_vertices: Array, triangle_indices: Array, canvas_size: Vector2i, output_path: String = "") -> Dictionary:
	var errors := _validate_inputs(source, source_uvs, destination_vertices, triangle_indices, canvas_size)
	if not errors.is_empty(): return _failure(errors)
	var output := Image.create(canvas_size.x, canvas_size.y, false, Image.FORMAT_RGBA8)
	output.fill(Color(0, 0, 0, 0))
	var ownership: Dictionary = {}
	var overlaps := 0
	var written := 0
	for index in range(0, triangle_indices.size(), 3):
		var a_index := int(triangle_indices[index]); var b_index := int(triangle_indices[index + 1]); var c_index := int(triangle_indices[index + 2])
		var a := _vec(destination_vertices[a_index]); var b := _vec(destination_vertices[b_index]); var c := _vec(destination_vertices[c_index])
		var uv_a := _vec(source_uvs[a_index]); var uv_b := _vec(source_uvs[b_index]); var uv_c := _vec(source_uvs[c_index])
		if _edge(a, b, c) < 0.0:
			var swap_vertex := b; b = c; c = swap_vertex
			var swap_uv := uv_b; uv_b = uv_c; uv_c = swap_uv
		var bounds := _bounds(a, b, c, canvas_size)
		for y in range(bounds.position.y, bounds.end.y):
			for x in range(bounds.position.x, bounds.end.x):
				var point := Vector2(x + 0.5, y + 0.5)
				if not _inside_top_left(a, b, c, point): continue
				var barycentric := _barycentric(a, b, c, point)
				var uv := uv_a * barycentric.x + uv_b * barycentric.y + uv_c * barycentric.z
				var source_x := int(floor(uv.x)); var source_y := int(floor(uv.y))
				if source_x < 0 or source_y < 0 or source_x >= source.get_width() or source_y >= source.get_height(): continue
				var key := Vector2i(x, y)
				if ownership.has(key): overlaps += 1
				ownership[key] = true
				output.set_pixel(x, y, source.get_pixel(source_x, source_y))
				written += 1
	var audit := _audit(source, output)
	if overlaps > 0: errors.append("Mesh triangles overlap on %d destination pixels." % overlaps)
	if not output_path.strip_edges().is_empty():
		var directory := output_path.get_base_dir()
		if not directory.is_empty(): DirAccess.make_dir_recursive_absolute(_absolute(directory))
		if output.save_png(output_path) != OK: errors.append("Strict bake could not write PNG: %s" % output_path)
	return {
		"success": errors.is_empty(), "errors": errors, "image": output, "baker_version": BAKER_VERSION,
		"output_hash": _image_hash(output), "pixels_written": written,
		"overlap_pixels": overlaps, "output_path": output_path, "audit": audit,
	}


static func _validate_inputs(source: Image, source_uvs: Array, destination_vertices: Array, indices: Array, canvas_size: Vector2i) -> Array[String]:
	var errors: Array[String] = []
	if source == null or source.is_empty(): errors.append("Strict bake requires a decoded source image.")
	if canvas_size.x <= 0 or canvas_size.y <= 0: errors.append("Strict bake canvas size must be positive.")
	if source_uvs.size() != destination_vertices.size() or source_uvs.size() < 3: errors.append("Strict bake needs one source UV for each destination vertex.")
	if indices.size() < 3 or indices.size() % 3 != 0: errors.append("Strict bake triangle indices must be non-empty triples.")
	for index in indices:
		if int(index) < 0 or int(index) >= destination_vertices.size(): errors.append("Strict bake has an out-of-range triangle index."); break
	return errors


static func _bounds(a: Vector2, b: Vector2, c: Vector2, canvas_size: Vector2i) -> Rect2i:
	var start_x := clampi(int(floor(minf(a.x, minf(b.x, c.x)))), 0, canvas_size.x)
	var start_y := clampi(int(floor(minf(a.y, minf(b.y, c.y)))), 0, canvas_size.y)
	var end_x := clampi(int(ceil(maxf(a.x, maxf(b.x, c.x)))), 0, canvas_size.x)
	var end_y := clampi(int(ceil(maxf(a.y, maxf(b.y, c.y)))), 0, canvas_size.y)
	return Rect2i(start_x, start_y, maxi(0, end_x - start_x), maxi(0, end_y - start_y))


static func _inside_top_left(a: Vector2, b: Vector2, c: Vector2, point: Vector2) -> bool:
	return _edge_owns(a, b, point) and _edge_owns(b, c, point) and _edge_owns(c, a, point)


static func _edge_owns(a: Vector2, b: Vector2, point: Vector2) -> bool:
	var value := _edge(a, b, point)
	if value > 0.0: return true
	if value < 0.0: return false
	return b.y < a.y or (is_equal_approx(a.y, b.y) and b.x > a.x)


static func _barycentric(a: Vector2, b: Vector2, c: Vector2, point: Vector2) -> Vector3:
	var area := _edge(a, b, c)
	return Vector3(_edge(b, c, point) / area, _edge(c, a, point) / area, _edge(a, b, point) / area)


static func _edge(a: Vector2, b: Vector2, point: Vector2) -> float:
	return (b.x - a.x) * (point.y - a.y) - (b.y - a.y) * (point.x - a.x)


static func _audit(source: Image, output: Image) -> Dictionary:
	var source_colors: Dictionary = {}; var output_colors: Dictionary = {}
	var source_alpha: Dictionary = {}; var partial_output := 0
	for y in range(source.get_height()):
		for x in range(source.get_width()):
			var source_color := source.get_pixel(x, y)
			source_colors[source_color.to_rgba32()] = true; source_alpha[source_color.a8] = true
	for y in range(output.get_height()):
		for x in range(output.get_width()):
			var output_color := output.get_pixel(x, y)
			output_colors[output_color.to_rgba32()] = true
			if output_color.a8 > 0 and output_color.a8 < 255 and not source_alpha.has(output_color.a8): partial_output += 1
	var outside_palette := 0
	for key in output_colors:
		if not source_colors.has(key): outside_palette += 1
	return {"source_color_subset": outside_palette == 0, "outside_source_color_count": outside_palette, "new_partial_alpha_pixels": partial_output, "source_rgba_count": source_colors.size(), "output_rgba_count": output_colors.size()}


static func _vec(value: Variant) -> Vector2:
	if value is Vector2: return value
	if value is Vector2i: return Vector2(value)
	if value is Array and (value as Array).size() >= 2: return Vector2(float(value[0]), float(value[1]))
	return Vector2.ZERO


static func _absolute(path: String) -> String:
	return ProjectSettings.globalize_path(path) if path.begins_with("res://") or path.begins_with("user://") else path


static func _image_hash(image: Image) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(image.get_data())
	return context.finish().hex_encode()


static func _failure(errors: Array[String]) -> Dictionary:
	return {"success": false, "errors": errors, "image": null, "audit": {}}
