# LpcFrameMeshFactory -- Deterministic rectangular, alpha-cell, and manual topology creation.
class_name LpcFrameMeshFactory
extends RefCounted

const MeshScript = preload("res://lpc/deformation/lpc_frame_mesh.gd")


static func rectangular_grid(source: Image, context: Dictionary, columns: int = 4, rows: int = 4, padding: int = 0) -> Dictionary:
	if source == null or source.is_empty():
		return {"success": false, "errors": ["A source frame is required for a rectangular mesh."]}
	var bounds := _alpha_bounds(source, 1)
	if bounds.size.x <= 0 or bounds.size.y <= 0:
		bounds = Rect2i(0, 0, source.get_width(), source.get_height())
	else:
		bounds = bounds.grow(maxi(0, padding)).intersection(Rect2i(0, 0, source.get_width(), source.get_height()))
	columns = maxi(1, columns)
	rows = maxi(1, rows)
	var vertices: Array = []
	var indices: Array = []
	for y in range(rows + 1):
		for x in range(columns + 1):
			vertices.append(Vector2(
				bounds.position.x + float(x) * float(bounds.size.x) / float(columns),
				bounds.position.y + float(y) * float(bounds.size.y) / float(rows)
			))
	for y in range(rows):
		for x in range(columns):
			var a := y * (columns + 1) + x
			var b := a + 1
			var c := a + columns + 1
			var d := c + 1
			indices.append_array([a, b, c, b, d, c])
	var mesh := MeshScript.create(_context(source, context), vertices, vertices, indices, {
		"mesh_id": str(context.get("mesh_id", "rect_mesh")),
		"boundary_edges": _boundary_edges(indices),
		"island_ids": _filled(vertices.size(), "island_0"),
		"provenance": {"strategy": "rectangular_grid", "padding": padding, "columns": columns, "rows": rows},
	})
	return {"success": true, "errors": [], "mesh": mesh}


static func alpha_aware(source: Image, context: Dictionary, alpha_threshold: int = 1) -> Dictionary:
	if source == null or source.is_empty():
		return {"success": false, "errors": ["A source frame is required for an alpha-aware mesh."]}
	alpha_threshold = clampi(alpha_threshold, 0, 255)
	var pixel_islands := _opaque_islands(source, alpha_threshold)
	var vertex_ids: Dictionary = {}
	var vertices: Array = []
	var island_ids: Array = []
	var indices: Array = []
	for y in range(source.get_height()):
		for x in range(source.get_width()):
			if source.get_pixel(x, y).a8 < alpha_threshold: continue
			var island_id := str(pixel_islands.get(_point_key(x, y), "island_0"))
			var a := _vertex(vertex_ids, vertices, island_ids, Vector2i(x, y), island_id)
			var b := _vertex(vertex_ids, vertices, island_ids, Vector2i(x + 1, y), island_id)
			var c := _vertex(vertex_ids, vertices, island_ids, Vector2i(x, y + 1), island_id)
			var d := _vertex(vertex_ids, vertices, island_ids, Vector2i(x + 1, y + 1), island_id)
			indices.append_array([a, b, c, b, d, c])
	if vertices.size() < 3:
		return rectangular_grid(source, context, 1, 1, 0)
	var island_names: Dictionary = {}
	for key in pixel_islands:
		island_names[str(pixel_islands[key])] = true
	var mesh := MeshScript.create(_context(source, context), vertices, vertices, indices, {
		"mesh_id": str(context.get("mesh_id", "alpha_mesh")),
		"alpha_threshold": alpha_threshold,
		"boundary_edges": _boundary_edges(indices),
		"island_ids": island_ids,
		"hole_records": _transparent_holes(source, alpha_threshold),
		"provenance": {
			"strategy": "alpha_pixel_cells",
			"island_count": island_names.size(),
			"preserves_holes": true,
			"triangulation": "deterministic_pixel_cells",
		},
	})
	return {"success": true, "errors": [], "mesh": mesh}


static func manual(context: Dictionary, rest_vertices: Array, uvs: Array, triangle_indices: Array, options: Dictionary = {}) -> Dictionary:
	var mesh_context := context.duplicate(true)
	var source: Image = options.get("source", null)
	if source != null and not source.is_empty(): mesh_context = _context(source, mesh_context)
	var mesh := MeshScript.create(mesh_context, rest_vertices, uvs, triangle_indices, {
		"mesh_id": str(options.get("mesh_id", "manual_mesh")),
		"boundary_edges": _boundary_edges(triangle_indices),
		"locked_vertices": (options.get("locked_vertices", []) as Array).duplicate(true),
		"control_vertices": (options.get("control_vertices", []) as Array).duplicate(true),
		"topology_group_id": str(options.get("topology_group_id", "")),
		"provenance": {"strategy": "manual_topology"},
	})
	var errors := MeshScript.validate(mesh)
	return {"success": errors.is_empty(), "errors": errors, "mesh": mesh}


static func image_hash(image: Image) -> String:
	var hashing := HashingContext.new()
	hashing.start(HashingContext.HASH_SHA256)
	hashing.update(image.get_data())
	return hashing.finish().hex_encode()


static func alpha_mask_hash(image: Image) -> String:
	var hashing := HashingContext.new()
	hashing.start(HashingContext.HASH_SHA256)
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			hashing.update(PackedByteArray([image.get_pixel(x, y).a8]))
	return hashing.finish().hex_encode()


static func _context(source: Image, context: Dictionary) -> Dictionary:
	var result := context.duplicate(true)
	result["source_frame_hash"] = image_hash(source)
	result["alpha_mask_hash"] = alpha_mask_hash(source)
	result["source_image_dimensions"] = [source.get_width(), source.get_height()]
	return result


static func _alpha_bounds(image: Image, threshold: int) -> Rect2i:
	var min_x := image.get_width()
	var min_y := image.get_height()
	var max_x := -1
	var max_y := -1
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			if image.get_pixel(x, y).a8 < threshold: continue
			min_x = mini(min_x, x)
			min_y = mini(min_y, y)
			max_x = maxi(max_x, x)
			max_y = maxi(max_y, y)
	return Rect2i(min_x, min_y, max_x - min_x + 1, max_y - min_y + 1) if max_x >= 0 else Rect2i()


static func _vertex(ids: Dictionary, vertices: Array, island_ids: Array, point: Vector2i, island_id: String) -> int:
	var key := _point_key(point.x, point.y)
	if ids.has(key): return int(ids[key])
	var index := vertices.size()
	ids[key] = index
	vertices.append(Vector2(point))
	island_ids.append(island_id)
	return index


static func _boundary_edges(indices: Array) -> Array:
	var counts: Dictionary = {}
	var directions: Dictionary = {}
	for offset in range(0, indices.size(), 3):
		var edges := [
			[int(indices[offset]), int(indices[offset + 1])],
			[int(indices[offset + 1]), int(indices[offset + 2])],
			[int(indices[offset + 2]), int(indices[offset])],
		]
		for edge in edges:
			var key := "%d:%d" % [mini(int(edge[0]), int(edge[1])), maxi(int(edge[0]), int(edge[1]))]
			counts[key] = int(counts.get(key, 0)) + 1
			directions[key] = edge
	var result: Array = []
	for key in counts:
		if int(counts[key]) == 1: result.append(directions[key])
	return result


static func _opaque_islands(image: Image, threshold: int) -> Dictionary:
	var result: Dictionary = {}
	var island_number := 0
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			var start := Vector2i(x, y)
			if image.get_pixelv(start).a8 < threshold or result.has(_point_key(x, y)): continue
			var pending: Array = [start]
			var island_id := "island_%d" % island_number
			island_number += 1
			while not pending.is_empty():
				var point: Vector2i = pending.pop_back()
				if point.x < 0 or point.y < 0 or point.x >= image.get_width() or point.y >= image.get_height(): continue
				var key := _point_key(point.x, point.y)
				if result.has(key) or image.get_pixelv(point).a8 < threshold: continue
				result[key] = island_id
				pending.append_array([point + Vector2i.LEFT, point + Vector2i.RIGHT, point + Vector2i.UP, point + Vector2i.DOWN])
	return result


static func _transparent_holes(image: Image, threshold: int) -> Array:
	var visited: Dictionary = {}
	var holes: Array = []
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			var start := Vector2i(x, y)
			var key := _point_key(x, y)
			if visited.has(key) or image.get_pixelv(start).a8 >= threshold: continue
			var pending: Array = [start]
			var pixels: Array = []
			var touches_edge := false
			while not pending.is_empty():
				var point: Vector2i = pending.pop_back()
				if point.x < 0 or point.y < 0 or point.x >= image.get_width() or point.y >= image.get_height(): continue
				var point_key := _point_key(point.x, point.y)
				if visited.has(point_key) or image.get_pixelv(point).a8 >= threshold: continue
				visited[point_key] = true
				pixels.append([point.x, point.y])
				touches_edge = touches_edge or point.x == 0 or point.y == 0 or point.x == image.get_width() - 1 or point.y == image.get_height() - 1
				pending.append_array([point + Vector2i.LEFT, point + Vector2i.RIGHT, point + Vector2i.UP, point + Vector2i.DOWN])
			if not touches_edge and not pixels.is_empty(): holes.append({"pixel_count": pixels.size(), "pixels": pixels})
	return holes


static func _filled(count: int, value: String) -> Array:
	var result: Array = []
	for _index in range(count): result.append(value)
	return result


static func _point_key(x: int, y: int) -> String:
	return "%d:%d" % [x, y]
