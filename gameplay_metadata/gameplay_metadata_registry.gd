# GameplayMetadataRegistry -- Per-clip metadata tracks plus reusable tags and variables.
class_name GameplayMetadataRegistry
extends RefCounted

var _tracks_by_clip: Dictionary = {}
var _tags: Dictionary = {}
var _variables: Dictionary = {}


func add_track(clip_id: String, track) -> bool:
	if clip_id.is_empty() or track == null or track.track_id.is_empty():
		return false
	if not _tracks_by_clip.has(clip_id):
		_tracks_by_clip[clip_id] = {}
	var tracks: Dictionary = _tracks_by_clip[clip_id]
	if tracks.has(track.track_id):
		return false
	tracks[track.track_id] = track.to_dict()
	return true


func get_track_data(clip_id: String) -> Array:
	var result: Array = []
	for track_data in (_tracks_by_clip.get(clip_id, {}) as Dictionary).values():
		result.append((track_data as Dictionary).duplicate(true))
	return result


func set_tag(tag_id: String, display_name: String, color: Color = Color.WHITE) -> bool:
	if tag_id.is_empty() or display_name.is_empty():
		return false
	_tags[tag_id] = {"tag_id": tag_id, "display_name": display_name, "color": color.to_html()}
	return true


func set_variable(variable_id: String, value: Variant, value_type: String = "variant") -> bool:
	if variable_id.is_empty() or value_type not in ["variant", "bool", "number", "string", "color"]:
		return false
	_variables[variable_id] = {"variable_id": variable_id, "value": value, "value_type": value_type}
	return true


func to_dict() -> Dictionary:
	return {
		"tracks_by_clip": _tracks_by_clip.duplicate(true),
		"tags": _tags.duplicate(true),
		"variables": _variables.duplicate(true)
	}


func from_dict(data: Dictionary) -> void:
	_tracks_by_clip = (data.get("tracks_by_clip", {}) as Dictionary).duplicate(true)
	_tags = (data.get("tags", {}) as Dictionary).duplicate(true)
	_variables = (data.get("variables", {}) as Dictionary).duplicate(true)
