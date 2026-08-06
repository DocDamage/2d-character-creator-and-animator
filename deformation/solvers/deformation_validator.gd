# DeformationValidator -- Diagnostic validator for mesh topology and skinning weight integrity.
# DEF-006: Validates unweighted vertices, degenerate zero-area triangles, and out-of-bounds UVs.
class_name DeformationValidator
extends RefCounted

## Validates MeshData integrity. Returns Array of diagnostic error string messages.
static func validate_mesh(mesh: RefCounted) -> Array[String]:
	var errors: Array[String] = []
	if mesh == null:
		errors.append("MeshData reference is null")
		return errors

	var verts: Array = mesh.get("vertices")
	if verts.is_empty():
		errors.append("MeshData contains 0 vertices")

	var tris: Array = mesh.get("triangles")
	if tris.is_empty():
		errors.append("MeshData contains 0 triangles")

	# 1. Check unweighted vertices & invalid indices
	for i in range(verts.size()):
		var v: RefCounted = verts[i]
		if v.bone_weights.is_empty():
			errors.append("Vertex %d has zero bone weight influences assigned" % i)
		else:
			var total_w: float = 0.0
			for bw in v.bone_weights:
				total_w += float(bw.weight)
			if absf(total_w - 1.0) > 0.01:
				errors.append("Vertex %d bone weight sum is %.3f (expected 1.0)" % [i, total_w])

		var uv: Vector2 = v.uv
		if uv.x < -0.1 or uv.x > 1.1 or uv.y < -0.1 or uv.y > 1.1:
			errors.append("Vertex %d has out-of-bounds UV coordinates: %s" % [i, str(uv)])

	# 2. Check triangle index validity and degenerate zero-area triangles
	var v_count: int = verts.size()
	for t_idx in range(tris.size()):
		var tri: Array = tris[t_idx] as Array
		if tri.size() < 3:
			errors.append("Triangle %d has fewer than 3 indices" % t_idx)
			continue

		var i0: int = tri[0]
		var i1: int = tri[1]
		var i2: int = tri[2]

		if i0 < 0 or i0 >= v_count or i1 < 0 or i1 >= v_count or i2 < 0 or i2 >= v_count:
			errors.append("Triangle %d contains out-of-range vertex index: %s" % [t_idx, str(tri)])
			continue

		if i0 == i1 or i1 == i2 or i2 == i0:
			errors.append("Triangle %d contains duplicate vertex indices: %s" % [t_idx, str(tri)])
			continue

		var p0: Vector2 = verts[i0].position
		var p1: Vector2 = verts[i1].position
		var p2: Vector2 = verts[i2].position

		var area: float = absf((p0.x * (p1.y - p2.y) + p1.x * (p2.y - p0.y) + p2.x * (p0.y - p1.y)) * 0.5)
		if area <= 1e-6:
			errors.append("Triangle %d is degenerate with zero surface area" % t_idx)

	return errors
