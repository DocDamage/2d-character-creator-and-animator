# LpcFrameMesh -- Versioned, frame-bound mesh data for strict LPC raster warps.
class_name LpcFrameMesh
extends RefCounted

const SCHEMA_VERSION := "2.0.0"
const REQUIRED_KEYS := [
	"mesh_schema_version", "mesh_id", "source_asset_id", "source_asset_sha256",
	"source_frame_hash", "source_frame_reference", "source_image_dimensions",
	"rest_vertices", "uvs", "triangle_indices", "control_state",
]


static func create(context: Dictionary, rest_vertices: Array, uvs: Array, triangle_indices: Array, options: Dictionary = {}) -> Dictionary:
	var source_reference: Dictionary = (context.get("source_frame_reference", {}) as Dictionary).duplicate(true)
	var dimensions: Array = (context.get("source_image_dimensions", []) as Array).duplicate(true)
	return {
		"mesh_schema_version": SCHEMA_VERSION,
		"mesh_id": str(options.get("mesh_id", "lpc_mesh_" + str(Time.get_ticks_usec()))),
		"topology_version": int(options.get("topology_version", 1)),
		"source_asset_id": str(context.get("source_asset_id", "")),
		"source_asset_sha256": str(context.get("source_hash", context.get("source_asset_sha256", ""))),
		"source_frame_hash": str(context.get("source_frame_hash", "")),
		"source_frame_reference": source_reference,
		"source_image_dimensions": dimensions,
		"alpha_mask_hash": str(context.get("alpha_mask_hash", "")),
		"alpha_threshold": maxi(0, int(options.get("alpha_threshold", 1))),
		"rest_vertices": serialize_vectors(rest_vertices),
		"uvs": serialize_vectors(uvs),
		"triangle_indices": triangle_indices.duplicate(true),
		"boundary_edges": (options.get("boundary_edges", []) as Array).duplicate(true),
		"island_ids": (options.get("island_ids", []) as Array).duplicate(true),
		"hole_records": (options.get("hole_records", []) as Array).duplicate(true),
		"control_vertices": (options.get("control_vertices", []) as Array).duplicate(true),
		"locked_vertices": (options.get("locked_vertices", []) as Array).duplicate(true),
		"topology_group_id": str(options.get("topology_group_id", "")),
		"deformation_mode": str(options.get("deformation_mode", "strict_lpc_raster")),
		"output_bounds_policy": str(options.get("output_bounds_policy", "source_canvas")),
		"quality_thresholds": {
			"max_area_ratio": float(options.get("max_area_ratio", 4.0)),
			"max_edge_stretch": float(options.get("max_edge_stretch", 3.0)),
			"min_coverage": float(options.get("min_coverage", 1.0)),
		},
		"provenance": (options.get("provenance", {}) as Dictionary).duplicate(true),
		"solver_version": "lpc-frame-controls-1.0.0",
		"baker_version": "lpc-strict-frame-1.0.0",
		"control_state": default_control_state(options.get("control_state", {})),
	}


static func default_control_state(value: Variant = {}) -> Dictionary:
	var state: Dictionary = (value as Dictionary).duplicate(true) if value is Dictionary else {}
	if not state.has("vertex_offsets"): state["vertex_offsets"] = {}
	if not state.has("pins"): state["pins"] = []
	if not state.has("lattice"): state["lattice"] = {}
	if not state.has("soft_drags"): state["soft_drags"] = []
	if not state.has("cage"): state["cage"] = {}
	if not state.has("bone_offsets"): state["bone_offsets"] = {}
	if not state.has("evaluation_order"): state["evaluation_order"] = ["cage", "lattice", "pins", "soft_drags", "bones", "vertex_offsets"]
	return state


static func validate(mesh: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	for key in REQUIRED_KEYS:
		if not mesh.has(key): errors.append("LPC frame mesh is missing '%s'." % key)
	if str(mesh.get("mesh_schema_version", "")) != SCHEMA_VERSION:
		errors.append("Unsupported LPC frame mesh schema '%s'." % mesh.get("mesh_schema_version", ""))
	if str(mesh.get("mesh_id", "")).strip_edges().is_empty(): errors.append("LPC frame mesh needs a stable mesh_id.")
	var vertices: Array = mesh.get("rest_vertices", [])
	var uvs: Array = mesh.get("uvs", [])
	var indices: Array = mesh.get("triangle_indices", [])
	if vertices.size() < 3 or uvs.size() != vertices.size():
		errors.append("LPC frame mesh needs matching rest vertices and UVs.")
	if indices.size() < 3 or indices.size() % 3 != 0:
		errors.append("LPC frame mesh requires triangle index triples.")
	for index in indices:
		if int(index) < 0 or int(index) >= vertices.size():
			errors.append("LPC frame mesh has an out-of-range triangle index.")
			break
	var dimensions: Array = mesh.get("source_image_dimensions", [])
	if dimensions.size() != 2 or int(dimensions[0]) <= 0 or int(dimensions[1]) <= 0:
		errors.append("LPC frame mesh has invalid source dimensions.")
	if not mesh.get("control_state", {}) is Dictionary:
		errors.append("LPC frame mesh control state must be an object.")
	return errors


static func migrate(raw: Dictionary) -> Dictionary:
	var mesh := raw.duplicate(true)
	if str(mesh.get("mesh_schema_version", "")) == SCHEMA_VERSION:
		mesh["control_state"] = default_control_state(mesh.get("control_state", {}))
		return {"success": true, "changed": false, "mesh": mesh, "errors": []}
	if str(mesh.get("schema_version", "")) != "1.0.0" and not mesh.has("vertices"):
		return {"success": false, "changed": false, "mesh": mesh, "errors": ["Cannot migrate unknown LPC frame mesh schema."]}
	var vertices: Array = mesh.get("rest_vertices", mesh.get("vertices", []))
	var triangles: Array = mesh.get("triangle_indices", mesh.get("triangles", []))
	if not triangles.is_empty() and triangles[0] is Array:
		var flattened: Array = []
		for triangle in triangles:
			for value in triangle:
				flattened.append(int(value))
		triangles = flattened
	mesh["mesh_schema_version"] = SCHEMA_VERSION
	mesh["mesh_id"] = str(mesh.get("mesh_id", "migrated_lpc_mesh"))
	mesh["topology_version"] = int(mesh.get("topology_version", 1))
	mesh["rest_vertices"] = serialize_vectors(vertices)
	mesh["uvs"] = serialize_vectors(mesh.get("uvs", vertices))
	mesh["triangle_indices"] = triangles
	mesh["source_asset_id"] = str(mesh.get("source_asset_id", mesh.get("texture_asset_id", "legacy_source")))
	mesh["source_asset_sha256"] = str(mesh.get("source_asset_sha256", "legacy_unbound"))
	mesh["source_frame_hash"] = str(mesh.get("source_frame_hash", "legacy_unbound"))
	mesh["source_frame_reference"] = (mesh.get("source_frame_reference", {}) as Dictionary).duplicate(true)
	mesh["source_image_dimensions"] = (mesh.get("source_image_dimensions", [64, 64]) as Array).duplicate(true)
	mesh["alpha_mask_hash"] = str(mesh.get("alpha_mask_hash", ""))
	mesh["alpha_threshold"] = int(mesh.get("alpha_threshold", 1))
	mesh["boundary_edges"] = (mesh.get("boundary_edges", []) as Array).duplicate(true)
	mesh["island_ids"] = (mesh.get("island_ids", []) as Array).duplicate(true)
	mesh["hole_records"] = (mesh.get("hole_records", []) as Array).duplicate(true)
	mesh["control_vertices"] = (mesh.get("control_vertices", []) as Array).duplicate(true)
	mesh["locked_vertices"] = (mesh.get("locked_vertices", []) as Array).duplicate(true)
	mesh["topology_group_id"] = str(mesh.get("topology_group_id", ""))
	mesh["deformation_mode"] = str(mesh.get("deformation_mode", "strict_lpc_raster"))
	mesh["output_bounds_policy"] = str(mesh.get("output_bounds_policy", "source_canvas"))
	mesh["quality_thresholds"] = (mesh.get("quality_thresholds", {"max_area_ratio": 4.0, "max_edge_stretch": 3.0, "min_coverage": 1.0}) as Dictionary).duplicate(true)
	mesh["provenance"] = (mesh.get("provenance", {"strategy": "migrated_legacy_mesh"}) as Dictionary).duplicate(true)
	mesh["solver_version"] = "lpc-frame-controls-1.0.0"
	mesh["baker_version"] = "lpc-strict-frame-1.0.0"
	mesh["control_state"] = default_control_state(mesh.get("control_state", {}))
	return {"success": true, "changed": true, "mesh": mesh, "errors": []}


static func vectors(values: Array) -> Array[Vector2]:
	var result: Array[Vector2] = []
	for value in values:
		result.append(_as_vector(value))
	return result


static func serialize_vectors(values: Array) -> Array:
	var result: Array = []
	for value in values:
		var vector := _as_vector(value)
		result.append([vector.x, vector.y])
	return result


static func _as_vector(value: Variant) -> Vector2:
	if value is Vector2: return value
	if value is Vector2i: return Vector2(value)
	if value is Array and (value as Array).size() >= 2:
		return Vector2(float((value as Array)[0]), float((value as Array)[1]))
	return Vector2.ZERO
