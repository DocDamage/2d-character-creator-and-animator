# DopeSheet -- Dope sheet model: track rows, visible range, selected keys, scrub position
# ANM-003: Implement dope sheet
class_name DopeSheet
extends RefCounted

## The clip this dope sheet is editing.
var clip = null

## The track registry providing the track rows.
var track_registry = null

## Current playhead time in seconds.
var scrub_time: float = 0.0

## Visible time range [start, end] in seconds.
var view_start: float = 0.0
var view_end: float = 1.0

## IDs of tracks that are currently expanded.
var expanded_track_ids: Array = []

## Set of selected { "track_id": String, "key_id": String } entries.
var selected_keys: Array = []

## Optional search/filter term for filtering visible track rows.
var filter_term: String = ""


func _init(p_clip = null, p_registry = null) -> void:
	clip = p_clip
	track_registry = p_registry
	if p_clip != null:
		view_end = p_clip.duration


## Return the list of track rows currently visible given filter_term.
func get_visible_tracks() -> Array:
	if track_registry == null:
		return []
	if filter_term.is_empty():
		return track_registry.list_all()
	var lower := filter_term.to_lower()
	var result: Array = []
	for t in track_registry.list_all():
		if t.object_id.to_lower().contains(lower) or t.property_path.to_lower().contains(lower):
			result.append(t)
	return result


## Expand a track row.
func expand_track(track_id: String) -> void:
	if not expanded_track_ids.has(track_id):
		expanded_track_ids.append(track_id)


## Collapse a track row.
func collapse_track(track_id: String) -> void:
	expanded_track_ids.erase(track_id)


## Toggle expansion state of a track.
func toggle_expand(track_id: String) -> void:
	if expanded_track_ids.has(track_id):
		collapse_track(track_id)
	else:
		expand_track(track_id)


## Add a key to the dope sheet selection.
func select_key(track_id: String, key_id: String) -> void:
	for entry in selected_keys:
		if entry.get("track_id") == track_id and entry.get("key_id") == key_id:
			return
	selected_keys.append({"track_id": track_id, "key_id": key_id})


## Clear key selection.
func deselect_all() -> void:
	selected_keys.clear()


## Move the scrub head.
func set_scrub_time(t: float) -> void:
	scrub_time = clampf(t, 0.0, clip.duration if clip != null else 1e9)


## Set the visible time range.
func set_view_range(start: float, end: float) -> void:
	if end <= start:
		return
	view_start = maxf(0.0, start)
	view_end = end


## Return keys for a track that fall within the visible time range.
func get_visible_keys(track) -> Array:
	var result: Array = []
	for k in track.get_sorted_keys():
		var t := float(k.get("time", 0.0))
		if t >= view_start and t <= view_end:
			result.append(k)
	return result
