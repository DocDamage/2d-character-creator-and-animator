# MeshData -- Serialisable 2D mesh, vertex, and bone weight schemas.
# MSH-001: Defines MeshData, VertexData, and BoneWeightData schemas for deformation studio.
class_name MeshData
extends RefCounted

const SCHEMA_VERSION := "1.0.0"

## Inner class for individual bone weight influence on a vertex.
class BoneWeightData:
	extends RefCounted
	var bone_id: String = ""
	var weight: float = 1.0

	func _init(p_bone: String = "", p_weight: float = 1.0) -> void:
		bone_id = p_bone
		weight = clampf(p_weight, 0.0, 1.0)

	func to_dict() -> Dictionary:
		return {"bone_id": bone_id, "weight": weight}

	func from_dict(d: Dictionary) -> BoneWeightData:
		bone_id = str(d.get("bone_id", ""))
		weight = clampf(float(d.get("weight", 1.0)), 0.0, 1.0)
		return self


## Inner class for individual 2D mesh vertex.
class VertexData:
	extends RefCounted
	var vertex_id: int = 0
	var position: Vector2 = Vector2.ZERO
	var uv: Vector2 = Vector2.ZERO
	var bone_weights: Array = [] # Array of BoneWeightData

	func _init(p_id: int = 0, p_pos: Vector2 = Vector2.ZERO, p_uv: Vector2 = Vector2.ZERO) -> void:
		vertex_id = p_id
		position = p_pos
		uv = p_uv

	func to_dict() -> Dictionary:
		var weights_arr: Array = []
		for bw in bone_weights:
			if bw != null and bw.has_method("to_dict"):
				weights_arr.append(bw.to_dict())
		return {
			"vertex_id": vertex_id,
			"position": [position.x, position.y],
			"uv": [uv.x, uv.y],
			"bone_weights": weights_arr
		}

	func from_dict(d: Dictionary) -> VertexData:
		vertex_id = int(d.get("vertex_id", 0))
		var pos_arr: Array = d.get("position", [0.0, 0.0])
		position = Vector2(float(pos_arr[0]), float(pos_arr[1])) if pos_arr.size() >= 2 else Vector2.ZERO
		var uv_arr: Array = d.get("uv", [0.0, 0.0])
		uv = Vector2(float(uv_arr[0]), float(uv_arr[1])) if uv_arr.size() >= 2 else Vector2.ZERO
		bone_weights.clear()
		var weights_data: Array = d.get("bone_weights", [])
		for bw_dict in weights_data:
			if typeof(bw_dict) == TYPE_DICTIONARY:
				var bw := BoneWeightData.new()
				bw.from_dict(bw_dict as Dictionary)
				bone_weights.append(bw)
		return self


## MeshData root attributes.
var mesh_id: String = ""
var vertices: Array = [] # Array of VertexData
var triangles: Array = [] # Array of PackedInt32Array or Array of int triplets [v0, v1, v2]
var texture_asset_id: String = ""


func _init(p_id: String = "") -> void:
	mesh_id = p_id


func add_vertex(pos: Vector2, uv: Vector2) -> VertexData:
	var v_id: int = vertices.size()
	var v := VertexData.new(v_id, pos, uv)
	vertices.append(v)
	return v


func add_triangle(v0: int, v1: int, v2: int) -> void:
	triangles.append([v0, v1, v2])


func to_dict() -> Dictionary:
	var vert_dicts: Array = []
	for v in vertices:
		if v != null and v.has_method("to_dict"):
			vert_dicts.append(v.to_dict())
	return {
		"schema_version": SCHEMA_VERSION,
		"mesh_id": mesh_id,
		"texture_asset_id": texture_asset_id,
		"vertices": vert_dicts,
		"triangles": triangles
	}


func from_dict(d: Dictionary) -> MeshData:
	mesh_id = str(d.get("mesh_id", ""))
	texture_asset_id = str(d.get("texture_asset_id", ""))
	vertices.clear()
	var vert_arr: Array = d.get("vertices", [])
	for v_dict in vert_arr:
		if typeof(v_dict) == TYPE_DICTIONARY:
			var v := VertexData.new()
			v.from_dict(v_dict as Dictionary)
			vertices.append(v)
	triangles = d.get("triangles", []).duplicate()
	return self
