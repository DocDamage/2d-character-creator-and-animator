# AnimationEventTrack -- Discrete event, notify, and custom-payload timeline triggers.
class_name AnimationEventTrack
extends "res://animation/tracks/track_schema.gd"


func _init(p_id: String = "", p_obj: String = "", p_path: String = "") -> void:
	track_id = p_id
	object_id = p_obj
	property_path = p_path
	track_type = TrackType.EVENT


func add_event(time: float, event_id: String, event_name: String, event_type: String = "notify", payload: Dictionary = {}) -> Dictionary:
	var event := {
		"event_id": event_id,
		"event_name": event_name,
		"event_type": event_type,
		"payload": payload.duplicate(true)
	}
	var key := {"key_id": event_id, "time": time, "value": event, "interpolation": Interpolation.STEPPED, "easing": 0.0}
	keys.append(key)
	return key


func get_events_between(from_time: float, to_time: float, include_start: bool = false) -> Array:
	var result: Array = []
	if to_time < from_time:
		return result
	for key in get_sorted_keys():
		var key_time := float(key.get("time", 0.0))
		if (key_time >= from_time if include_start else key_time > from_time) and key_time <= to_time:
			var event: Dictionary = (key.get("value", {}) as Dictionary).duplicate(true)
			event["time"] = key_time
			result.append(event)
	return result


func validate() -> Array:
	var errors := super.validate()
	for key in keys:
		var event: Dictionary = key.get("value", {})
		if str(event.get("event_id", "")).is_empty() or str(event.get("event_name", "")).is_empty():
			errors.append("AnimationEventTrack contains an incomplete event")
	return errors
