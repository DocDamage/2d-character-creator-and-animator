# TrackRegistry -- Per-clip registry of TrackDefinition objects
# ANM-004: Implement per-object tracks
class_name TrackRegistry
extends RefCounted

const TrackDefinitionScript = preload("res://animation/tracks/track_schema.gd")
const TrackFactoryScript = preload("res://animation/tracks/track_factory.gd")

## Internal storage: track_id (String) -> TrackDefinition
var _tracks: Dictionary = {}

## The clip this registry belongs to.
var clip_id: String = ""


func _init(p_clip_id: String = "") -> void:
	clip_id = p_clip_id


## Add a track. Returns false if the track_id is already registered.
func add_track(track) -> bool:
	if track == null or track.track_id.is_empty():
		push_error("TrackRegistry.add_track: track must have a non-empty track_id")
		return false
	if _tracks.has(track.track_id):
		return false
	_tracks[track.track_id] = track
	return true


## Remove a track by ID. Returns true if found and removed.
func remove_track(track_id: String) -> bool:
	if _tracks.has(track_id):
		_tracks.erase(track_id)
		return true
	return false


## Retrieve a track by ID.
func get_track(track_id: String):
	return _tracks.get(track_id, null)


## List all tracks belonging to a specific object_id.
func get_tracks_for_object(object_id: String) -> Array:
	var result: Array = []
	for t in _tracks.values():
		if t.object_id == object_id:
			result.append(t)
	return result


## List all tracks of a specific type integer value.
func get_tracks_of_type(track_type: int) -> Array:
	var result: Array = []
	for t in _tracks.values():
		if t.track_type == track_type:
			result.append(t)
	return result


## Return all tracks.
func list_all() -> Array:
	return _tracks.values()


## Return track count.
func count() -> int:
	return _tracks.size()


## Clear all tracks.
func clear() -> void:
	_tracks.clear()


## Serialize all tracks.
func to_dict_array() -> Array:
	var result: Array = []
	for t in _tracks.values():
		result.append(t.to_dict())
	return result


## Load from serialized track dictionaries.
func load_from_dict_array(arr: Array) -> Array:
	var errors: Array = []
	clear()
	for d in arr:
		var t = TrackFactoryScript.from_dict(d as Dictionary)
		var errs: Array = t.validate()
		if errs.is_empty():
			if not add_track(t):
				errors.append("Duplicate track_id: " + t.track_id)
		else:
			errors.append_array(errs)
	return errors
