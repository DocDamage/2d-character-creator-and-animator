# CollisionShapeTrack -- Stepped hitbox or hurtbox shape snapshots for a timeline.
class_name CollisionShapeTrack
extends "res://animation/tracks/track_schema.gd"

var collision_kind: String = "hitbox"


func _init(p_id: String = "", p_obj: String = "", p_path: String = "", p_kind: String = "hitbox") -> void:
	track_id = p_id
	object_id = p_obj
	property_path = p_path
	collision_kind = p_kind
	track_type = TrackType.HITBOX if p_kind == "hitbox" else TrackType.HURTBOX


func add_shapes_key(time: float, shapes: Array, key_id: String) -> Dictionary:
	var serialized: Array = []
	for shape in shapes:
		serialized.append(shape.to_dict() if shape != null and shape.has_method("to_dict") else (shape as Dictionary).duplicate(true))
	var key := {"key_id": key_id, "time": time, "value": serialized, "interpolation": Interpolation.STEPPED, "easing": 0.0}
	keys.append(key)
	return key


func evaluate_shapes(time: float) -> Array:
	var current: Array = []
	for key in get_sorted_keys():
		if float(key.get("time", 0.0)) > time:
			break
		current = (key.get("value", []) as Array).duplicate(true)
	return current


func validate() -> Array:
	var errors := super.validate()
	if collision_kind not in ["hitbox", "hurtbox"]:
		errors.append("CollisionShapeTrack collision_kind must be hitbox or hurtbox")
	for key in keys:
		for shape_data in key.get("value", []):
			var shape := CollisionShapeDefinition.new()
			errors.append_array(shape.from_dict(shape_data).validate())
	return errors
