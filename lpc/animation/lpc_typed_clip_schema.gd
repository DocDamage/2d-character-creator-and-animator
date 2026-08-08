# LpcTypedClipSchema -- LPC clip validation and deterministic project serialization.
class_name LpcTypedClipSchema
extends RefCounted

const SCHEMA_VERSION := "1.0.0"
const TrackSchemaScript = preload("res://lpc/animation/lpc_typed_track_schema.gd")


static func create(clip_id: String, name: String, options: Dictionary = {}) -> Dictionary:
	return {"clip_schema_version": SCHEMA_VERSION, "clip_id": clip_id, "name": name, "duration": maxf(0.1, float(options.get("duration", 0.9))), "fps": maxf(1.0, float(options.get("fps", 10.0))), "loop": bool(options.get("loop", true)), "default_animation_id": str(options.get("default_animation_id", "walk")), "default_direction_id": str(options.get("default_direction_id", "down")), "tracks": (options.get("tracks", []) as Array).duplicate(true), "notes": str(options.get("notes", "")), "metadata": (options.get("metadata", {}) as Dictionary).duplicate(true)}


static func validate(clip: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	if str(clip.get("clip_schema_version", "")).is_empty(): errors.append("LPC clip is missing clip_schema_version.")
	if str(clip.get("clip_id", "")).is_empty(): errors.append("LPC clip is missing clip_id.")
	if str(clip.get("name", "")).strip_edges().is_empty(): errors.append("LPC clip name cannot be empty.")
	if float(clip.get("duration", 0.0)) <= 0.0: errors.append("LPC clip duration must be positive.")
	if float(clip.get("fps", 0.0)) <= 0.0: errors.append("LPC clip fps must be positive.")
	var ids: Dictionary = {}
	for raw_track in clip.get("tracks", []):
		if not raw_track is Dictionary: errors.append("LPC clip contains an invalid track."); continue
		var track: Dictionary = raw_track; var track_id := str(track.get("track_id", ""))
		if ids.has(track_id): errors.append("LPC clip has duplicate track '%s'." % track_id)
		ids[track_id] = true; errors.append_array(TrackSchemaScript.validate(track))
	return errors


static func add_track(clip: Dictionary, track: Dictionary) -> Dictionary:
	var result := clip.duplicate(true); var tracks: Array = (result.get("tracks", []) as Array).duplicate(true); var replaced := false
	for index in range(tracks.size()):
		if tracks[index] is Dictionary and str((tracks[index] as Dictionary).get("track_id", "")) == str(track.get("track_id", "")): tracks[index] = track.duplicate(true); replaced = true
	if not replaced: tracks.append(track.duplicate(true))
	tracks.sort_custom(func(a: Dictionary, b: Dictionary): return str(a.get("track_id", "")) < str(b.get("track_id", ""))); result["tracks"] = tracks; return result


static func find(profile: Dictionary, clip_id: String) -> Dictionary:
	for raw_clip in profile.get("clips", []):
		if raw_clip is Dictionary and str((raw_clip as Dictionary).get("clip_id", "")) == clip_id: return (raw_clip as Dictionary).duplicate(true)
	return {}
