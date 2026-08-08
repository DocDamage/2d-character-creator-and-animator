# LpcDeformationDiagnostics -- Strict geometry, source, coverage, palette, and alpha audits.
class_name LpcDeformationDiagnostics
extends RefCounted

const MeshScript = preload("res://lpc/deformation/lpc_frame_mesh.gd")


static func inspect(mesh: Dictionary, source: Image, evaluated_vertices: Array = [], baked: Dictionary = {}) -> Dictionary:
	var errors := MeshScript.validate(mesh)
	var warnings: Array[String] = []
	var metrics: Dictionary = {}
	if source == null or source.is_empty():
		errors.append("Strict deformation requires a decoded source frame.")
		return _report(errors, warnings, metrics)
	var dimensions: Array = mesh.get("source_image_dimensions", [])
	if dimensions.size() == 2 and (int(dimensions[0]) != source.get_width() or int(dimensions[1]) != source.get_height()):
		errors.append("Mesh source dimensions do not match the decoded frame.")
	var expected_hash := str(mesh.get("source_frame_hash", ""))
	if not expected_hash.is_empty() and expected_hash != "legacy_unbound" and expected_hash != image_hash(source):
		errors.append("Mesh source binding does not match this frame hash.")
	var expected_mask := str(mesh.get("alpha_mask_hash", ""))
	if not expected_mask.is_empty() and expected_mask != alpha_mask_hash(source):
		errors.append("Mesh alpha-mask binding does not match this frame.")
	var rest := MeshScript.vectors(mesh.get("rest_vertices", []))
	var destination := MeshScript.vectors(evaluated_vertices if not evaluated_vertices.is_empty() else mesh.get("rest_vertices", []))
	var uvs := MeshScript.vectors(mesh.get("uvs", []))
	var indices: Array = mesh.get("triangle_indices", [])
	if destination.size() != rest.size(): errors.append("Evaluated mesh vertex count does not match rest geometry.")
	_validate_uvs(uvs, source.get_size(), errors)
	var geometry := _geometry_checks(rest, destination, indices, mesh, errors, warnings)
	metrics.merge(geometry, true)
	_validate_bake(source, baked, mesh, errors, warnings, metrics)
	return _report(errors, warnings, metrics)


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


static func _validate_uvs(uvs: Array[Vector2], source_size: Vector2, errors: Array[String]) -> void:
	for uv in uvs:
		if uv.x < 0.0 or uv.y < 0.0 or uv.x > source_size.x or uv.y > source_size.y:
			errors.append("Mesh UV lies outside the declared source frame.")
			return


static func _geometry_checks(rest: Array[Vector2], destination: Array[Vector2], indices: Array, mesh: Dictionary, errors: Array[String], warnings: Array[String]) -> Dictionary:
	var unique_triangles: Dictionary = {}
	var unique_edges: Dictionary = {}
	var max_area_ratio := 0.0
	var max_stretch := 0.0
	var triangle_count := 0
	for offset in range(0, indices.size(), 3):
		if offset + 2 >= indices.size(): break
		var a := int(indices[offset])
		var b := int(indices[offset + 1])
		var c := int(indices[offset + 2])
		if a < 0 or b < 0 or c < 0 or a >= rest.size() or b >= rest.size() or c >= rest.size(): continue
		if a == b or b == c or a == c:
			errors.append("Mesh contains a triangle with duplicate indices.")
			continue
		var triangle_key := [a, b, c]
		triangle_key.sort()
		var key := "%d:%d:%d" % [triangle_key[0], triangle_key[1], triangle_key[2]]
		if unique_triangles.has(key): errors.append("Mesh contains duplicate triangles.")
		unique_triangles[key] = true
		var rest_area := _cross(rest[a], rest[b], rest[c])
		var destination_area := _cross(destination[a], destination[b], destination[c])
		if absf(rest_area) < 0.00001:
			errors.append("Mesh rest geometry contains a degenerate triangle.")
			continue
		if absf(destination_area) < 0.00001:
			errors.append("Evaluated deformation contains a degenerate triangle.")
		if rest_area * destination_area < 0.0:
			errors.append("Evaluated deformation flips triangle winding.")
		var area_ratio := absf(destination_area / rest_area)
		max_area_ratio = maxf(max_area_ratio, area_ratio)
		for edge in [[a, b], [b, c], [c, a]]:
			var left := int(edge[0])
			var right := int(edge[1])
			var edge_key := "%d:%d" % [mini(left, right), maxi(left, right)]
			if unique_edges.has(edge_key): continue
			unique_edges[edge_key] = true
			var rest_length := rest[left].distance_to(rest[right])
			var evaluated_length := destination[left].distance_to(destination[right])
			if rest_length > 0.00001: max_stretch = maxf(max_stretch, evaluated_length / rest_length)
		triangle_count += 1
	var thresholds: Dictionary = mesh.get("quality_thresholds", {})
	if max_area_ratio > float(thresholds.get("max_area_ratio", 4.0)):
		warnings.append("Deformation exceeds the configured triangle-area quality threshold.")
	if max_stretch > float(thresholds.get("max_edge_stretch", 3.0)):
		warnings.append("Deformation exceeds the configured edge-stretch quality threshold.")
	if triangle_count <= 64:
		if _has_triangle_overlap(destination, indices): errors.append("Evaluated mesh has triangle self-overlap.")
	else:
		warnings.append("Triangle self-overlap audit was bounded for this high-density alpha mesh.")
	var boundaries: Array = mesh.get("boundary_edges", [])
	if boundaries.size() <= 128 and _has_boundary_crossing(destination, boundaries): errors.append("Mesh boundary self-intersects.")
	if _outside_canvas(destination, mesh.get("source_image_dimensions", [])):
		warnings.append("Deformation extends beyond the source-canvas bounds and will be clipped by strict bake.")
	return {"triangle_count": triangle_count, "max_area_ratio": max_area_ratio, "max_edge_stretch": max_stretch}


static func _validate_bake(source: Image, baked: Dictionary, mesh: Dictionary, errors: Array[String], warnings: Array[String], metrics: Dictionary) -> void:
	if baked.is_empty(): return
	for message in baked.get("errors", []): errors.append(str(message))
	if int(baked.get("overlap_pixels", 0)) > 0: errors.append("Strict bake reports shared-edge overlap pixels.")
	var audit: Dictionary = baked.get("audit", {})
	if not audit.is_empty():
		if not bool(audit.get("source_color_subset", false)): errors.append("Strict bake sampled a color outside the source palette.")
		if int(audit.get("new_partial_alpha_pixels", 0)) > 0: errors.append("Strict bake introduced new partial alpha values.")
		metrics["palette_audit"] = audit.duplicate(true)
	var output: Image = baked.get("image", null)
	if output == null or output.is_empty(): return
	var source_opaque := _opaque_count(source)
	var output_opaque := _opaque_count(output)
	var coverage := float(output_opaque) / float(source_opaque) if source_opaque > 0 else 1.0
	metrics["source_opaque_pixels"] = source_opaque
	metrics["output_opaque_pixels"] = output_opaque
	metrics["coverage_ratio"] = coverage
	if output_opaque == 0 and source_opaque > 0: errors.append("Strict bake left no covered opaque pixels.")
	var minimum := float((mesh.get("quality_thresholds", {}) as Dictionary).get("min_coverage", 1.0))
	if coverage < minimum: warnings.append("Strict bake coverage is below the configured quality threshold.")


static func _has_triangle_overlap(vertices: Array[Vector2], indices: Array) -> bool:
	for left_offset in range(0, indices.size(), 3):
		if left_offset + 2 >= indices.size(): break
		var left := [int(indices[left_offset]), int(indices[left_offset + 1]), int(indices[left_offset + 2])]
		for right_offset in range(left_offset + 3, indices.size(), 3):
			if right_offset + 2 >= indices.size(): break
			var right := [int(indices[right_offset]), int(indices[right_offset + 1]), int(indices[right_offset + 2])]
			if _shares_vertex(left, right): continue
			if _triangles_intersect(vertices[left[0]], vertices[left[1]], vertices[left[2]], vertices[right[0]], vertices[right[1]], vertices[right[2]]): return true
	return false


static func _has_boundary_crossing(vertices: Array[Vector2], boundaries: Array) -> bool:
	for left_index in range(boundaries.size()):
		if not boundaries[left_index] is Array or (boundaries[left_index] as Array).size() < 2: continue
		var left: Array = boundaries[left_index]
		for right_index in range(left_index + 1, boundaries.size()):
			if not boundaries[right_index] is Array or (boundaries[right_index] as Array).size() < 2: continue
			var right: Array = boundaries[right_index]
			if _shares_vertex(left, right): continue
			var a := int(left[0]); var b := int(left[1]); var c := int(right[0]); var d := int(right[1])
			if a < 0 or b < 0 or c < 0 or d < 0 or a >= vertices.size() or b >= vertices.size() or c >= vertices.size() or d >= vertices.size(): continue
			if _segments_intersect(vertices[a], vertices[b], vertices[c], vertices[d]): return true
	return false


static func _triangles_intersect(a: Vector2, b: Vector2, c: Vector2, d: Vector2, e: Vector2, f: Vector2) -> bool:
	for first in [[a, b], [b, c], [c, a]]:
		for second in [[d, e], [e, f], [f, d]]:
			if _segments_intersect(first[0], first[1], second[0], second[1]): return true
	return _point_in_triangle(a, d, e, f) or _point_in_triangle(d, a, b, c)


static func _point_in_triangle(point: Vector2, a: Vector2, b: Vector2, c: Vector2) -> bool:
	var one := _cross(a, b, point)
	var two := _cross(b, c, point)
	var three := _cross(c, a, point)
	return (one >= 0.0 and two >= 0.0 and three >= 0.0) or (one <= 0.0 and two <= 0.0 and three <= 0.0)


static func _segments_intersect(a: Vector2, b: Vector2, c: Vector2, d: Vector2) -> bool:
	var ab_c := _cross(a, b, c)
	var ab_d := _cross(a, b, d)
	var cd_a := _cross(c, d, a)
	var cd_b := _cross(c, d, b)
	var epsilon := 0.00001
	if ((ab_c > epsilon and ab_d < -epsilon) or (ab_c < -epsilon and ab_d > epsilon)) and ((cd_a > epsilon and cd_b < -epsilon) or (cd_a < -epsilon and cd_b > epsilon)):
		return true
	if absf(ab_c) <= epsilon and _on_segment(a, b, c): return true
	if absf(ab_d) <= epsilon and _on_segment(a, b, d): return true
	if absf(cd_a) <= epsilon and _on_segment(c, d, a): return true
	if absf(cd_b) <= epsilon and _on_segment(c, d, b): return true
	return false


static func _on_segment(a: Vector2, b: Vector2, point: Vector2) -> bool:
	return point.x >= minf(a.x, b.x) - 0.00001 and point.x <= maxf(a.x, b.x) + 0.00001 and point.y >= minf(a.y, b.y) - 0.00001 and point.y <= maxf(a.y, b.y) + 0.00001


static func _shares_vertex(left: Array, right: Array) -> bool:
	for value in left:
		for other in right:
			if int(value) == int(other): return true
	return false


static func _outside_canvas(vertices: Array[Vector2], dimensions: Array) -> bool:
	if dimensions.size() != 2: return false
	for point in vertices:
		if point.x < 0.0 or point.y < 0.0 or point.x > float(dimensions[0]) or point.y > float(dimensions[1]): return true
	return false


static func _opaque_count(image: Image) -> int:
	var count := 0
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			if image.get_pixel(x, y).a8 > 0: count += 1
	return count


static func _cross(a: Vector2, b: Vector2, c: Vector2) -> float:
	return (b.x - a.x) * (c.y - a.y) - (b.y - a.y) * (c.x - a.x)


static func _report(errors: Array[String], warnings: Array[String], metrics: Dictionary) -> Dictionary:
	return {"success": errors.is_empty(), "errors": errors, "warnings": warnings, "metrics": metrics}
