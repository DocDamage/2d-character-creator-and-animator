# ClipRegistry -- Schema-driven registry for all animation clips in a project
# ANM-001: data-driven clip management; ANM-002: clip browser support
class_name ClipRegistry
extends RefCounted

const AnimationClipScript = preload("res://animation/clips/clip_schema.gd")

## Internal storage: clip_id (String) -> AnimationClip
var _clips: Dictionary = {}

## Optional project-level metadata.
var project_id: String = ""


## Register a new clip. Accepts any RefCounted with clip_id and clip_name.
## Returns false if the ID is already taken.
func register(clip) -> bool:
	if clip == null or clip.clip_id.is_empty():
		push_error("ClipRegistry.register: clip must have a non-empty clip_id")
		return false
	if _clips.has(clip.clip_id):
		return false
	_clips[clip.clip_id] = clip
	return true


## Remove a clip by ID. Returns true if found and removed.
func unregister(clip_id: String) -> bool:
	if _clips.has(clip_id):
		_clips.erase(clip_id)
		return true
	return false


## Retrieve a clip by ID. Returns null if not found.
func get_clip(clip_id: String):
	return _clips.get(clip_id, null)


## Return all clips as an Array.
func list_all() -> Array:
	return _clips.values()


## Return clips whose names contain the search term (case-insensitive).
func search(term: String) -> Array:
	var result: Array = []
	var lower := term.to_lower()
	for clip in _clips.values():
		if clip.clip_name.to_lower().contains(lower):
			result.append(clip)
	return result


## Return the number of registered clips.
func count() -> int:
	return _clips.size()


## Clear all clips.
func clear() -> void:
	_clips.clear()


## Serialize the entire registry to a list of clip dictionaries.
func to_dict_array() -> Array:
	var result: Array = []
	for clip in _clips.values():
		result.append(clip.to_dict())
	return result


## Populate from a serialized list of clip dictionaries.
## Returns Array of error strings encountered.
func load_from_dict_array(arr: Array) -> Array:
	var errors: Array = []
	clear()
	for d in arr:
		var clip = AnimationClipScript.new()
		clip.from_dict(d as Dictionary)
		var clip_errors := clip.validate()
		if clip_errors.is_empty():
			if not register(clip):
				errors.append("Duplicate clip_id: " + clip.clip_id)
		else:
			errors.append_array(clip_errors)
	return errors
