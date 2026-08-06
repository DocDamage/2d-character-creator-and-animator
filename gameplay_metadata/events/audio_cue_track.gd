# AudioCueTrack -- Discrete sound cues carrying volume, pan, and audio asset metadata.
class_name AudioCueTrack
extends "res://animation/tracks/track_schema.gd"


func _init(p_id: String = "", p_obj: String = "", p_path: String = "") -> void:
	track_id = p_id
	object_id = p_obj
	property_path = p_path
	track_type = TrackType.AUDIO_CUE


func add_cue(time: float, cue_id: String, audio_asset_id: String, volume_db: float = 0.0, pan: float = 0.0) -> Dictionary:
	var cue := {"cue_id": cue_id, "audio_asset_id": audio_asset_id, "volume_db": volume_db, "pan": clampf(pan, -1.0, 1.0)}
	var key := {"key_id": cue_id, "time": time, "value": cue, "interpolation": Interpolation.STEPPED, "easing": 0.0}
	keys.append(key)
	return key


func get_cues_between(from_time: float, to_time: float) -> Array:
	var cues: Array = []
	for key in get_sorted_keys():
		if float(key.get("time", 0.0)) > from_time and float(key.get("time", 0.0)) <= to_time:
			cues.append((key.get("value", {}) as Dictionary).duplicate(true))
	return cues


func validate() -> Array:
	var errors := super.validate()
	for key in keys:
		if str((key.get("value", {}) as Dictionary).get("audio_asset_id", "")).is_empty():
			errors.append("AudioCueTrack has a cue without audio_asset_id")
	return errors
