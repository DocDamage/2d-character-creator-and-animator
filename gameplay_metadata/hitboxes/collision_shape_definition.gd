# CollisionShapeDefinition -- Serializable hit, hurt, and gameplay collision volume.
class_name CollisionShapeDefinition
extends RefCounted

const SCHEMA_VERSION := "1.0.0"

enum ShapeType { RECTANGLE, CIRCLE, CAPSULE, CONVEX_POLYGON, SEGMENT, BONE_FOLLOWING }

var shape_id: String = ""
var display_name: String = ""
var shape_type: ShapeType = ShapeType.RECTANGLE
var local_position: Vector2 = Vector2.ZERO
var local_rotation: float = 0.0
var size: Vector2 = Vector2(16.0, 16.0)
var radius: float = 8.0
var points: PackedVector2Array = []
var bone_id: String = ""
var damage_region: String = ""
var enabled: bool = true


func _init(p_id: String = "", p_name: String = "", p_type: ShapeType = ShapeType.RECTANGLE) -> void:
	shape_id = p_id
	display_name = p_name
	shape_type = p_type


func get_local_bounds() -> Rect2:
	match shape_type:
		ShapeType.CIRCLE:
			return Rect2(local_position - Vector2.ONE * radius, Vector2.ONE * radius * 2.0)
		ShapeType.CONVEX_POLYGON:
			return _points_bounds()
		ShapeType.SEGMENT:
			return _points_bounds()
		_:
			return Rect2(local_position - size * 0.5, size)


func to_dict() -> Dictionary:
	var serialized_points: Array = []
	for point in points:
		serialized_points.append([point.x, point.y])
	return {
		"schema_version": SCHEMA_VERSION,
		"shape_id": shape_id,
		"display_name": display_name,
		"shape_type": shape_type,
		"local_position": [local_position.x, local_position.y],
		"local_rotation": local_rotation,
		"size": [size.x, size.y],
		"radius": radius,
		"points": serialized_points,
		"bone_id": bone_id,
		"damage_region": damage_region,
		"enabled": enabled
	}


func from_dict(data: Dictionary) -> CollisionShapeDefinition:
	shape_id = str(data.get("shape_id", ""))
	display_name = str(data.get("display_name", ""))
	shape_type = int(data.get("shape_type", ShapeType.RECTANGLE)) as ShapeType
	local_position = _as_vector2(data.get("local_position", Vector2.ZERO))
	local_rotation = float(data.get("local_rotation", 0.0))
	size = _as_vector2(data.get("size", [16.0, 16.0]))
	radius = float(data.get("radius", 8.0))
	points = _as_points(data.get("points", []))
	bone_id = str(data.get("bone_id", ""))
	damage_region = str(data.get("damage_region", ""))
	enabled = bool(data.get("enabled", true))
	return self


func validate() -> Array:
	var errors: Array = []
	if shape_id.is_empty():
		errors.append("CollisionShapeDefinition requires shape_id")
	if display_name.is_empty():
		errors.append("CollisionShapeDefinition '%s' requires display_name" % shape_id)
	if shape_type == ShapeType.CIRCLE and radius <= 0.0:
		errors.append("Circle shape '%s' requires positive radius" % shape_id)
	if shape_type == ShapeType.CONVEX_POLYGON and points.size() < 3:
		errors.append("Convex polygon '%s' requires at least three points" % shape_id)
	if shape_type == ShapeType.SEGMENT and points.size() != 2:
		errors.append("Segment '%s' requires exactly two points" % shape_id)
	if shape_type == ShapeType.BONE_FOLLOWING and bone_id.is_empty():
		errors.append("Bone-following shape '%s' requires bone_id" % shape_id)
	return errors


func resolve_global_transform(rig: Dictionary) -> Dictionary:
	if bone_id.is_empty() or not (rig.get("bones", {}) as Dictionary).has(bone_id):
		return {"position": local_position, "rotation": local_rotation}
	var manager := BoneManager.new()
	manager.initialize(rig)
	var bone_transform := manager.get_global_transform(bone_id)
	return {
		"position": bone_transform.origin + local_position.rotated(bone_transform.get_rotation()),
		"rotation": bone_transform.get_rotation() + local_rotation
	}


func _points_bounds() -> Rect2:
	if points.is_empty():
		return Rect2(local_position, Vector2.ZERO)
	var bounds := Rect2(points[0], Vector2.ZERO)
	for point in points.slice(1):
		bounds = bounds.expand(point)
	return bounds


static func _as_vector2(value: Variant) -> Vector2:
	if value is Vector2:
		return value
	if value is Array and value.size() >= 2:
		return Vector2(float(value[0]), float(value[1]))
	return Vector2.ZERO


static func _as_points(value: Array) -> PackedVector2Array:
	var result := PackedVector2Array()
	for point in value:
		result.append(_as_vector2(point))
	return result
