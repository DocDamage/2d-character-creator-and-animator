# TimelinePersistence -- Save and reload the full animation timeline state
# ANM-014: Implement timeline persistence
class_name TimelinePersistence
extends RefCounted

const ClipRegistryScript = preload("res://animation/clips/clip_registry.gd")
const AnimationClipScript = preload("res://animation/clips/clip_schema.gd")
const TrackRegistryScript = preload("res://animation/tracks/track_registry.gd")
const MarkerRegionScript = preload("res://animation/timeline/marker_region.gd")

## Schema version for migration support.
const SCHEMA_VERSION := "1.0.0"


## Serialize a ClipRegistry + per-clip TrackRegistries to a single project-storable Dictionary.
## track_registries: Dictionary { clip_id: String -> TrackRegistry }
## marker_registries: Dictionary { clip_id: String -> MarkerRegion } (optional)
static func serialize(
	clip_registry,
	track_registries: Dictionary,
	marker_registries: Dictionary = {}
) -> Dictionary:
	var clips_arr: Array = []
	for clip in clip_registry.list_all():
		var clip_dict: Dictionary = clip.to_dict()
		# Inline track data.
		var treg = track_registries.get(clip.clip_id, null)
		if treg != null:
			clip_dict["tracks"] = treg.to_dict_array()
		# Inline marker/region data.
		var mreg = marker_registries.get(clip.clip_id, null)
		if mreg != null:
			var md: Dictionary = mreg.to_dict()
			clip_dict["markers"] = md.get("markers", [])
			clip_dict["regions"] = md.get("regions", [])
		clips_arr.append(clip_dict)
	return {
		"schema_version": SCHEMA_VERSION,
		"clips": clips_arr
	}


## Deserialize a timeline dictionary into a ClipRegistry and track/marker registries.
## Returns a Dictionary with keys:
##   "clip_registry":      ClipRegistry
##   "track_registries":   Dictionary { clip_id -> TrackRegistry }
##   "marker_registries":  Dictionary { clip_id -> MarkerRegion }
##   "errors":             Array of String error messages
static func deserialize(data: Dictionary) -> Dictionary:
	var out_clip_reg = ClipRegistryScript.new()
	var out_track_regs: Dictionary = {}
	var out_marker_regs: Dictionary = {}
	var out_errors: Array = []

	for cd in data.get("clips", []):
		var clip_dict := cd as Dictionary
		var clip = AnimationClipScript.new()
		clip.from_dict(clip_dict)
		var clip_errors: Array = clip.validate()
		if not clip_errors.is_empty():
			out_errors.append_array(clip_errors)
			continue
		if not out_clip_reg.register(clip):
			out_errors.append("Duplicate clip_id during load: " + clip.clip_id)
			continue
		# Deserialize tracks.
		var treg = TrackRegistryScript.new(clip.clip_id)
		var track_errors: Array = treg.load_from_dict_array(clip_dict.get("tracks", []))
		out_errors.append_array(track_errors)
		out_track_regs[clip.clip_id] = treg
		# Deserialize markers.
		var mreg = MarkerRegionScript.new()
		mreg.from_dict({
			"markers": clip_dict.get("markers", []),
			"regions": clip_dict.get("regions", [])
		})
		out_marker_regs[clip.clip_id] = mreg

	return {
		"clip_registry": out_clip_reg,
		"track_registries": out_track_regs,
		"marker_registries": out_marker_regs,
		"errors": out_errors
	}


## Validate a serialized timeline dictionary. Returns Array of error strings.
static func validate(data: Dictionary) -> Array:
	var errors: Array = []
	if not data.has("clips"):
		errors.append("Timeline data missing 'clips' key")
	else:
		for cd in data.get("clips", []):
			var clip = AnimationClipScript.new()
			clip.from_dict(cd as Dictionary)
			errors.append_array(clip.validate())
	return errors
