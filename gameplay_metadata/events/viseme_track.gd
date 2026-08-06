# VisemeTrack -- Stepped mouth/phoneme selection synchronized to timeline time.
class_name VisemeTrack
extends "res://animation/tracks/track_schema.gd"


func _init(p_id: String = "", p_obj: String = "", p_path: String = "") -> void:
	track_id = p_id
	object_id = p_obj
	property_path = p_path
	track_type = TrackType.VISEME


func add_viseme(time: float, viseme_id: String, mouth_attachment_id: String, key_id: String) -> Dictionary:
	var value := {"viseme_id": viseme_id, "mouth_attachment_id": mouth_attachment_id}
	var key := {"key_id": key_id, "time": time, "value": value, "interpolation": Interpolation.STEPPED, "easing": 0.0}
	keys.append(key)
	return key


func evaluate_viseme(time: float) -> Dictionary:
	var current: Dictionary = {}
	for key in get_sorted_keys():
		if float(key.get("time", 0.0)) > time:
			break
		current = (key.get("value", {}) as Dictionary).duplicate(true)
	return current


func validate() -> Array:
	var errors := super.validate()
	for key in keys:
		if str((key.get("value", {}) as Dictionary).get("viseme_id", "")).is_empty():
			errors.append("VisemeTrack contains an empty viseme_id")
	return errors
