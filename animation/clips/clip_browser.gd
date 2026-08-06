# ClipBrowser -- Read-only search/filter/select API over a ClipRegistry
# ANM-002: Implement clip browser
class_name ClipBrowser
extends RefCounted

## The backing registry. Assign before calling any query method.
var registry = null

## Currently active (selected) clip ID.
var active_clip_id: String = ""

## Most recent search term (retained for refresh).
var _last_search: String = ""


func _init(p_registry = null) -> void:
	registry = p_registry


## Return all clips, sorted alphabetically by clip_name.
func list_sorted() -> Array:
	if registry == null:
		return []
	var clips: Array = registry.list_all()
	clips.sort_custom(func(a, b): return a.clip_name < b.clip_name)
	return clips


## Return clips matching the search term.
func search(term: String) -> Array:
	if registry == null:
		return []
	_last_search = term
	if term.is_empty():
		return list_sorted()
	return registry.search(term)


## Activate (select) a clip by ID. Returns false if not found.
func activate(clip_id: String) -> bool:
	if registry == null:
		return false
	if registry.get_clip(clip_id) != null:
		active_clip_id = clip_id
		return true
	return false


## Return the currently active clip, or null.
func get_active_clip():
	if registry == null or active_clip_id.is_empty():
		return null
	return registry.get_clip(active_clip_id)


## Clear the active selection.
func deactivate() -> void:
	active_clip_id = ""


## Re-apply the last search term.
func refresh() -> Array:
	return search(_last_search)
