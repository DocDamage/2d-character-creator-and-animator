# FacingMeshBlendModel -- Validates and evaluates compatible directional mesh blends.
class_name FacingMeshBlendModel
extends RefCounted


static func evaluate_cells(from_cell: Dictionary, to_cell: Dictionary, weight: float) -> Dictionary:
	var validation := validate_cells(from_cell, to_cell)
	if not bool(validation["compatible"]):
		return validation
	var from_vertices := _mesh_vertices(from_cell)
	var to_vertices := _mesh_vertices(to_cell)
	var interpolated: Array = []
	for index in range(from_vertices.size()):
		interpolated.append((from_vertices[index] as Vector2).lerp(to_vertices[index] as Vector2, clampf(weight, 0.0, 1.0)))
	validation["vertices"] = interpolated
	validation["weight"] = clampf(weight, 0.0, 1.0)
	return validation


static func validate_cells(from_cell: Dictionary, to_cell: Dictionary) -> Dictionary:
	var from_mesh_id := str(from_cell.get("mesh_id", ""))
	var to_mesh_id := str(to_cell.get("mesh_id", ""))
	if from_mesh_id.is_empty() or to_mesh_id.is_empty():
		return _invalid("Both adjacent cells need a mesh ID.")
	if from_mesh_id != to_mesh_id:
		return _invalid("Adjacent cells use different mesh IDs.")
	var from_deformation := from_cell.get("deformation", {}) as Dictionary
	var to_deformation := to_cell.get("deformation", {}) as Dictionary
	if not bool(from_deformation.get("mesh_blend_enabled", true)) or not bool(to_deformation.get("mesh_blend_enabled", true)):
		return _invalid("Mesh blending is disabled for an adjacent cell.")
	var from_topology := str(from_deformation.get("topology_id", ""))
	var to_topology := str(to_deformation.get("topology_id", ""))
	if not from_topology.is_empty() and not to_topology.is_empty() and from_topology != to_topology:
		return _invalid("Adjacent cells use different topology IDs.")
	var from_vertices := _mesh_vertices(from_cell)
	var to_vertices := _mesh_vertices(to_cell)
	if from_vertices.is_empty() or to_vertices.is_empty():
		return _invalid("Both adjacent cells need deformation vertices.")
	if from_vertices.size() != to_vertices.size():
		return _invalid("Adjacent cells have different vertex counts.")
	return {
		"compatible": true,
		"reason": "",
		"mesh_id": from_mesh_id,
		"topology_id": from_topology if not from_topology.is_empty() else to_topology,
		"vertex_count": from_vertices.size(),
		"vertices": [],
		"weight": 0.0,
	}


static func _mesh_vertices(cell: Dictionary) -> Array:
	var deformation := cell.get("deformation", {}) as Dictionary
	var values: Array = deformation.get("mesh_vertices", deformation.get("vertices", [])) as Array
	var vertices: Array = []
	for value in values:
		if value is Vector2:
			vertices.append(value)
		elif value is Array and value.size() >= 2:
			vertices.append(Vector2(float(value[0]), float(value[1])))
		else:
			return []
	return vertices


static func _invalid(reason: String) -> Dictionary:
	return {"compatible": false, "reason": reason, "vertices": [], "weight": 0.0}
