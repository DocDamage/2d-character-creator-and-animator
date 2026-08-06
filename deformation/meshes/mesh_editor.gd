# MeshEditor -- Interactive manual topology editor for 2D mesh manipulation.
# MSH-003: Vertex insertion, deletion, edge splitting, and boundary modification.
class_name MeshEditor
extends RefCounted

signal mesh_modified()

var mesh: RefCounted = null # MeshData reference


func _init(p_mesh: RefCounted = null) -> void:
	mesh = p_mesh


## Inserts a new vertex at pos with given uv, reconnecting triangles if inside a triangle.
func insert_vertex(pos: Vector2, uv: Vector2) -> int:
	if mesh == null:
		return -1

	var new_v = mesh.add_vertex(pos, uv)
	var new_id: int = int(new_v.get("vertex_id"))

	# Find enclosing triangle
	var tris: Array = mesh.get("triangles")
	var tri_idx: int = -1

	for i in range(tris.size()):
		var tri: Array = tris[i] as Array
		var v0: Vector2 = mesh.vertices[tri[0]].position
		var v1: Vector2 = mesh.vertices[tri[1]].position
		var v2: Vector2 = mesh.vertices[tri[2]].position
		if is_point_in_triangle(pos, v0, v1, v2):
			tri_idx = i
			break

	if tri_idx >= 0:
		# Split enclosed triangle into 3 sub-triangles
		var orig_tri: Array = tris[tri_idx] as Array
		tris.remove_at(tri_idx)

		mesh.add_triangle(orig_tri[0], orig_tri[1], new_id)
		mesh.add_triangle(orig_tri[1], orig_tri[2], new_id)
		mesh.add_triangle(orig_tri[2], orig_tri[0], new_id)

	mesh_modified.emit()
	return new_id


## Deletes a vertex by index and removes all connected triangles.
func delete_vertex(vertex_id: int) -> bool:
	if mesh == null or vertex_id < 0 or vertex_id >= mesh.vertices.size():
		return false

	# Remove connected triangles
	var tris: Array = mesh.get("triangles")
	for i in range(tris.size() - 1, -1, -1):
		var tri: Array = tris[i] as Array
		if tri[0] == vertex_id or tri[1] == vertex_id or tri[2] == vertex_id:
			tris.remove_at(i)

	mesh_modified.emit()
	return true


## Splits an edge (v0, v1) by inserting a midpoint vertex.
func split_edge(v0: int, v1: int) -> int:
	if mesh == null:
		return -1

	var vert0 = mesh.vertices[v0]
	var vert1 = mesh.vertices[v1]
	var mid_pos: Vector2 = (vert0.position + vert1.position) * 0.5
	var mid_uv: Vector2 = (vert0.uv + vert1.uv) * 0.5

	var mid_id = mesh.add_vertex(mid_pos, mid_uv).vertex_id

	# Split all triangles containing edge (v0, v1)
	var tris: Array = mesh.get("triangles")
	for i in range(tris.size() - 1, -1, -1):
		var tri: Array = tris[i] as Array
		if has_edge_indices(tri, v0, v1):
			var other_v: int = get_third_vertex(tri, v0, v1)
			tris.remove_at(i)
			mesh.add_triangle(v0, mid_id, other_v)
			mesh.add_triangle(mid_id, v1, other_v)

	mesh_modified.emit()
	return mid_id


static func is_point_in_triangle(p: Vector2, a: Vector2, b: Vector2, c: Vector2) -> bool:
	var d1: float = sign_test(p, a, b)
	var d2: float = sign_test(p, b, c)
	var d3: float = sign_test(p, c, a)
	var has_neg: bool = (d1 < 0) or (d2 < 0) or (d3 < 0)
	var has_pos: bool = (d1 > 0) or (d2 > 0) or (d3 > 0)
	return not (has_neg and has_pos)


static func sign_test(p1: Vector2, p2: Vector2, p3: Vector2) -> float:
	return (p1.x - p3.x) * (p2.y - p3.y) - (p2.x - p3.x) * (p1.y - p3.y)


static func has_edge_indices(tri: Array, v0: int, v1: int) -> bool:
	return (tri[0] == v0 and tri[1] == v1) or (tri[1] == v0 and tri[0] == v1) or \
	       (tri[1] == v0 and tri[2] == v1) or (tri[2] == v0 and tri[1] == v1) or \
	       (tri[2] == v0 and tri[0] == v1) or (tri[0] == v0 and tri[2] == v1)


static func get_third_vertex(tri: Array, v0: int, v1: int) -> int:
	for idx in tri:
		if idx != v0 and idx != v1:
			return idx
	return -1
