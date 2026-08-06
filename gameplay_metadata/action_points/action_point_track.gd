# ActionPointTrack -- Keyframeable named locator track with position and orientation.
class_name ActionPointTrack
extends "res://animation/tracks/track_schema.gd"


func _init(p_id: String = "", p_obj: String = "", p_path: String = "") -> void:
	track_id = p_id
	object_id = p_obj
	property_path = p_path
	track_type = TrackType.ACTION_POINT


func add_action_point_key(time: float, point, key_id: String) -> Dictionary:
	var value: Dictionary = point.to_dict() if point != null and point.has_method("to_dict") else point.duplicate(true)
	var key := {"key_id": key_id, "time": time, "value": value, "interpolation": Interpolation.LINEAR, "easing": 0.0}
	keys.append(key)
	return key


func evaluate_action_point(time: float) -> Dictionary:
	var sorted := get_sorted_keys()
	if sorted.is_empty():
		return {}
	var previous: Dictionary = sorted[0]
	for key in sorted.slice(1):
		var key_time := float(key.get("time", 0.0))
		if time < key_time:
			return _interpolate(previous, key, time)
		previous = key
	return (previous.get("value", {}) as Dictionary).duplicate(true)


func validate() -> Array:
	var errors := super.validate()
	for key in keys:
		if not (key.get("value", {}) is Dictionary):
			errors.append("ActionPointTrack key at t=%s must be a dictionary" % key.get("time", "?"))
	return errors


func _interpolate(from_key: Dictionary, to_key: Dictionary, time: float) -> Dictionary:
	var from_value: Dictionary = from_key.get("value", {})
	var to_value: Dictionary = to_key.get("value", {})
	if int(to_key.get("interpolation", Interpolation.LINEAR)) == Interpolation.STEPPED:
		return from_value.duplicate(true)
	var start := float(from_key.get("time", 0.0))
	var end := float(to_key.get("time", start))
	var weight := inverse_lerp(start, end, time) if end > start else 1.0
	var from_pos := ActionPointDefinition._as_vector2(from_value.get("local_position", Vector2.ZERO))
	var to_pos := ActionPointDefinition._as_vector2(to_value.get("local_position", from_pos))
	var result := from_value.duplicate(true)
	result["local_position"] = [lerpf(from_pos.x, to_pos.x, weight), lerpf(from_pos.y, to_pos.y, weight)]
	result["local_rotation"] = lerp_angle(float(from_value.get("local_rotation", 0.0)), float(to_value.get("local_rotation", 0.0)), weight)
	return result
