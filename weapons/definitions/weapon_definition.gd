# WeaponDefinition -- Data-driven weapon asset, grips, gameplay points, and sockets.
class_name WeaponDefinition
extends RefCounted

const SCHEMA_VERSION := "1.0.0"

var weapon_id: String = ""
var display_name: String = ""
var asset_id: String = ""
var interaction_family_id: String = ""
var supported_body_types: PackedStringArray = []
var grips: Dictionary = {}
var action_points: Dictionary = {}
var sockets: Dictionary = {}
var tags: PackedStringArray = []


func _init(p_id: String = "", p_name: String = "") -> void:
	weapon_id = p_id
	display_name = p_name


func add_grip(grip) -> bool:
	if grip == null or grip.grip_id.is_empty() or grips.has(grip.grip_id):
		return false
	grips[grip.grip_id] = grip.to_dict()
	return true


func get_grip(grip_id: String):
	if not grips.has(grip_id):
		return null
	var grip := GripDefinition.new()
	grip.from_dict(grips[grip_id])
	return grip


func set_action_point(point_id: String, point_data: Dictionary) -> bool:
	if point_id.is_empty() or str(point_data.get("name", "")).is_empty():
		return false
	action_points[point_id] = point_data.duplicate(true)
	return true


func is_compatible_with_body_type(body_type_id: String) -> bool:
	return supported_body_types.is_empty() or body_type_id in supported_body_types


func to_dict() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"weapon_id": weapon_id,
		"display_name": display_name,
		"asset_id": asset_id,
		"interaction_family_id": interaction_family_id,
		"supported_body_types": Array(supported_body_types),
		"grips": grips.duplicate(true),
		"action_points": action_points.duplicate(true),
		"sockets": sockets.duplicate(true),
		"tags": Array(tags)
	}


func from_dict(data: Dictionary) -> WeaponDefinition:
	weapon_id = str(data.get("weapon_id", ""))
	display_name = str(data.get("display_name", ""))
	asset_id = str(data.get("asset_id", ""))
	interaction_family_id = str(data.get("interaction_family_id", ""))
	supported_body_types = PackedStringArray(data.get("supported_body_types", []))
	grips = (data.get("grips", {}) as Dictionary).duplicate(true)
	action_points = (data.get("action_points", {}) as Dictionary).duplicate(true)
	sockets = (data.get("sockets", {}) as Dictionary).duplicate(true)
	tags = PackedStringArray(data.get("tags", []))
	return self


func validate() -> Array:
	var errors: Array = []
	if weapon_id.is_empty():
		errors.append("WeaponDefinition requires weapon_id")
	if display_name.is_empty():
		errors.append("WeaponDefinition '%s' requires display_name" % weapon_id)
	if asset_id.is_empty():
		errors.append("WeaponDefinition '%s' requires asset_id" % weapon_id)
	var primary_grips := 0
	for grip_data in grips.values():
		var grip := GripDefinition.new()
		errors.append_array(grip.from_dict(grip_data).validate())
		if grip.role == GripDefinition.Role.PRIMARY:
			primary_grips += 1
	if primary_grips == 0:
		errors.append("WeaponDefinition '%s' requires one primary grip" % weapon_id)
	if primary_grips > 1:
		errors.append("WeaponDefinition '%s' has multiple primary grips" % weapon_id)
	return errors
