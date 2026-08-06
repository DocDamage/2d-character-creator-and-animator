# AutoMeshGenerator -- Automated Delaunay triangulation and mesh generator.
# MSH-002: Generates 2D triangular mesh topology and UVs from sprite rect bounds and grid subdivisions.
class_name AutoMeshGenerator
extends RefCounted

const MeshDataScript = preload("res://deformation/meshes/mesh_data.gd")


## Generates a grid-based triangular MeshData instance for texture region.
static func generate_grid_mesh(mesh_id: String, rect: Rect2, grid_x: int = 4, grid_y: int = 4) -> RefCounted:
	var mesh = MeshDataScript.new(mesh_id)
	grid_x = max(1, grid_x)
	grid_y = max(1, grid_y)

	# 1. Generate vertices and UVs
	for y in range(grid_y + 1):
		var v_ratio: float = float(y) / float(grid_y)
		var pos_y: float = rect.position.y + v_ratio * rect.size.y

		for x in range(grid_x + 1):
			var u_ratio: float = float(x) / float(grid_x)
			var pos_x: float = rect.position.x + u_ratio * rect.size.x

			mesh.add_vertex(Vector2(pos_x, pos_y), Vector2(u_ratio, v_ratio))

	# 2. Generate quad triangles (2 triangles per grid cell)
	var cols: int = grid_x + 1

	for y in range(grid_y):
		for x in range(grid_x):
			var i0: int = y * cols + x
			var i1: int = i0 + 1
			var i2: int = (y + 1) * cols + x
			var i3: int = i2 + 1

			# Triangle 1 (top-left)
			mesh.add_triangle(i0, i1, i2)
			# Triangle 2 (bottom-right)
			mesh.add_triangle(i1, i3, i2)

	return mesh


## Computes Delaunay triangulation indices for an array of 2D points.
## Returns Array of triangle index triplets [ [v0,v1,v2], ... ].
static func delaunay_triangulate_points(points: Array[Vector2]) -> Array:
	var triangles: Array = []
	if points.size() < 3:
		return triangles

	# Bowyer-Watson Delaunay triangulation algorithm baseline
	var p_count: int = points.size()
	if p_count == 3:
		triangles.append([0, 1, 2])
		return triangles

	# Super-triangle bounding box
	var min_p: Vector2 = points[0]
	var max_p: Vector2 = points[0]

	for pt in points:
		min_p.x = minf(min_p.x, pt.x)
		min_p.y = minf(min_p.y, pt.y)
		max_p.x = maxf(max_p.x, pt.x)
		max_p.y = maxf(max_p.y, pt.y)

	var dx: float = max_p.x - min_p.x
	var dy: float = max_p.y - min_p.y
	var delta_max: float = maxf(dx, dy) * 2.0
	var mid: Vector2 = (min_p + max_p) * 0.5

	# Add super triangle vertices at end of points
	var st_v0 := Vector2(mid.x - 2.0 * delta_max, mid.y - delta_max)
	var st_v1 := Vector2(mid.x, mid.y + 2.0 * delta_max)
	var st_v2 := Vector2(mid.x + 2.0 * delta_max, mid.y - delta_max)

	var pts: Array[Vector2] = points.duplicate()
	pts.append(st_v0)
	pts.append(st_v1)
	pts.append(st_v2)

	var temp_tris: Array = [ [p_count, p_count + 1, p_count + 2] ]

	for i in range(p_count):
		var p: Vector2 = pts[i]
		var bad_tris: Array = []

		for tri in temp_tris:
			if is_point_in_circumcircle(p, pts[tri[0]], pts[tri[1]], pts[tri[2]]):
				bad_tris.append(tri)

		var polygon: Array = []

		for tri in bad_tris:
			var edges := [ [tri[0], tri[1]], [tri[1], tri[2]], [tri[2], tri[0]] ]
			for edge in edges:
				var is_shared: bool = false
				for other_tri in bad_tris:
					if other_tri == tri:
						continue
					if has_edge(other_tri, edge[0], edge[1]):
						is_shared = true
						break
				if not is_shared:
					polygon.append(edge)

		for tri in bad_tris:
			temp_tris.erase(tri)

		for edge in polygon:
			temp_tris.append([edge[0], edge[1], i])

	# Filter out super-triangle vertices
	for tri in temp_tris:
		if tri[0] < p_count and tri[1] < p_count and tri[2] < p_count:
			triangles.append(tri)

	return triangles


static func is_point_in_circumcircle(p: Vector2, a: Vector2, b: Vector2, c: Vector2) -> bool:
	var ab: float = a.length_squared()
	var cd: float = b.length_squared()
	var ef: float = c.length_squared()

	var circum_x: float = (ab * (c.y - b.y) + cd * (a.y - c.y) + ef * (b.y - a.y)) / (2.0 * (a.x * (c.y - b.y) + b.x * (a.y - c.y) + c.x * (b.y - a.y)) + 1e-10)
	var circum_y: float = (ab * (b.x - c.x) + cd * (c.x - a.x) + ef * (a.x - b.x)) / (2.0 * (a.x * (c.y - b.y) + b.x * (a.y - c.y) + c.x * (b.y - a.y)) + 1e-10)
	var center := Vector2(circum_x, circum_y)
	var radius: float = a.distance_to(center)
	return p.distance_to(center) <= radius


static func has_edge(tri: Array, e0: int, e1: int) -> bool:
	var t0: int = tri[0]
	var t1: int = tri[1]
	var t2: int = tri[2]
	return (t0 == e0 and t1 == e1) or (t0 == e1 and t1 == e0) or \
	       (t1 == e0 and t2 == e1) or (t1 == e1 and t2 == e0) or \
	       (t2 == e0 and t0 == e1) or (t2 == e1 and t0 == e0)
