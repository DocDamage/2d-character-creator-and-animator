# UVEditor -- Texture UV coordinate mapping, normalization, and projection controller.
# MSH-004: Texture UV coordinate remapping, tile transform, normalization, and planar projection.
class_name UVEditor
extends RefCounted

## Remaps UV coordinates of all vertices using a texture rect bounds.
static func normalize_uvs(mesh: RefCounted, texture_rect: Rect2) -> void:
	if mesh == null or texture_rect.size.x <= 0.0 or texture_rect.size.y <= 0.0:
		return

	var verts: Array = mesh.get("vertices")
	for v in verts:
		var pos: Vector2 = v.position
		var norm_u: float = clampf((pos.x - texture_rect.position.x) / texture_rect.size.x, 0.0, 1.0)
		var norm_v: float = clampf((pos.y - texture_rect.position.y) / texture_rect.size.y, 0.0, 1.0)
		v.uv = Vector2(norm_u, norm_v)


## Transforms UV coordinates by scale, offset, and rotation angle in radians.
static func transform_uvs(mesh: RefCounted, scale: Vector2, offset: Vector2, rotation: float = 0.0) -> void:
	if mesh == null:
		return

	var verts: Array = mesh.get("vertices")
	var cos_r: float = cos(rotation)
	var sin_r: float = sin(rotation)

	for v in verts:
		var uv: Vector2 = v.uv
		# 1. Scale
		var scaled := Vector2(uv.x * scale.x, uv.y * scale.y)
		# 2. Rotate around center (0.5, 0.5)
		var rel := scaled - Vector2(0.5, 0.5)
		var rot := Vector2(rel.x * cos_r - rel.y * sin_r, rel.x * sin_r + rel.y * cos_r) + Vector2(0.5, 0.5)
		# 3. Translate offset
		v.uv = rot + offset


## Projects planar UVs along a bounding direction.
static func planar_project_uvs(mesh: RefCounted, direction: Vector2 = Vector2.RIGHT) -> void:
	if mesh == null or direction.length_squared() < 1e-6:
		return

	var dir: Vector2 = direction.normalized()
	var perp: Vector2 = Vector2(-dir.y, dir.x)

	var verts: Array = mesh.get("vertices")
	if verts.is_empty():
		return

	var min_u: float = INF
	var max_u: float = -INF
	var min_v: float = INF
	var max_v: float = -INF

	var proj_coords: Array[Vector2] = []

	for v in verts:
		var u_val: float = (v.position as Vector2).dot(dir)
		var v_val: float = (v.position as Vector2).dot(perp)
		min_u = minf(min_u, u_val)
		max_u = maxf(max_u, u_val)
		min_v = minf(min_v, v_val)
		max_v = maxf(max_v, v_val)
		proj_coords.append(Vector2(u_val, v_val))

	var range_u: float = max_u - min_u if max_u > min_u else 1.0
	var range_v: float = max_v - min_v if max_v > min_v else 1.0

	for i in range(verts.size()):
		var coord: Vector2 = proj_coords[i]
		verts[i].uv = Vector2((coord.x - min_u) / range_u, (coord.y - min_v) / range_v)
