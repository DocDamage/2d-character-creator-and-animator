# KeyEditor -- Multi-key selection, movement, scaling, ripple, and cross-clip copy/paste
# ANM-006: Multi-key editing; ANM-007: Timing scale, stretch, ripple; ANM-008: Cross-clip copy/paste
class_name KeyEditor
extends RefCounted

## Selected key entries: Array of { "track": track_obj, "key_id": String }
var selection: Array = []


## Add a key to the selection.
func select_key(track, key_id: String) -> void:
	for entry in selection:
		if entry.get("track") == track and entry.get("key_id") == key_id:
			return
	selection.append({"track": track, "key_id": key_id})


## Clear the current selection.
func deselect_all() -> void:
	selection.clear()


## Move all selected keys by a time delta. Clamps to >= 0.
func move_selected(delta_time: float) -> void:
	for entry in selection:
		var track = entry.get("track")
		var kid: String = entry.get("key_id")
		for k in track.keys:
			if k.get("key_id") == kid:
				k["time"] = maxf(0.0, float(k.get("time", 0.0)) + delta_time)
				break


## Scale selected key times around a pivot time.
## scale_factor > 1 stretches; < 1 compresses.
func scale_selected(pivot: float, scale_factor: float) -> void:
	if absf(scale_factor) < 0.0001:
		return
	for entry in selection:
		var track = entry.get("track")
		var kid: String = entry.get("key_id")
		for k in track.keys:
			if k.get("key_id") == kid:
				var t: float = float(k.get("time", 0.0))
				k["time"] = maxf(0.0, pivot + (t - pivot) * scale_factor)
				break


## Ripple: shift all keys on a track that are at or after threshold_time
## by ripple_delta seconds. Useful for insert/delete ripple edits.
static func ripple_track(track, threshold_time: float, ripple_delta: float) -> void:
	for k in track.keys:
		var t := float(k.get("time", 0.0))
		if t >= threshold_time:
			k["time"] = maxf(0.0, t + ripple_delta)


## Copy selected keys to a clipboard Dictionary keyed by track_id.
## Returns clipboard dict suitable for paste_from_clipboard().
func copy_to_clipboard() -> Dictionary:
	var cb: Dictionary = {}
	for entry in selection:
		var track = entry.get("track")
		var kid: String = entry.get("key_id")
		for k in track.keys:
			if k.get("key_id") == kid:
				if not cb.has(track.track_id):
					cb[track.track_id] = {
						"object_id": track.object_id,
						"property_path": track.property_path,
						"track_type": track.track_type,
						"keys": []
					}
				cb[track.track_id]["keys"].append(k.duplicate())
				break
	return cb


## Paste from clipboard into a destination TrackRegistry.
## time_offset shifts all pasted keys by the given seconds.
## Destination track is looked up by matching object_id + property_path.
## If no matching track exists, paste is skipped for that entry.
## Returns count of keys pasted.
func paste_from_clipboard(
	clipboard: Dictionary,
	dest_registry,
	factory,
	time_offset: float = 0.0
) -> int:
	var pasted := 0
	for src_track_id in clipboard.keys():
		var entry: Dictionary = clipboard[src_track_id]
		var obj_id: String = entry.get("object_id", "")
		var prop: String = entry.get("property_path", "")
		# Find a matching track in the destination registry.
		var dest_track = null
		for t in dest_registry.list_all():
			if t.object_id == obj_id and t.property_path == prop:
				dest_track = t
				break
		if dest_track == null:
			continue
		for k in entry.get("keys", []):
			var new_time := maxf(0.0, float(k.get("time", 0.0)) + time_offset)
			factory.create_key(dest_track, new_time, k.get("value"), k.get("interpolation", 1))
			pasted += 1
	return pasted
