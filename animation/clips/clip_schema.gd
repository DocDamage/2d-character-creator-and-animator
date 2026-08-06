# AnimationClip -- Core data schema for a named animation clip
# ANM-001: Defines clip, track, key, and property schemas
class_name AnimationClip
extends RefCounted

## Schema version for migration support.
const SCHEMA_VERSION := "1.0.0"

## Loop modes supported by the playback clock.
enum LoopMode { NONE, LOOP, PING_PONG }

## Stable unique identifier.
var clip_id: String = ""

## Human-readable display name.
var clip_name: String = "Untitled"

## Total duration in seconds.
var duration: float = 1.0

## Frames per second used when converting frame numbers to time.
var fps: float = 24.0

## Ordered list of TrackDefinition dictionaries serialized inline.
var tracks: Array = []

## Ordered list of MarkerData dictionaries.
var markers: Array = []

## Ordered list of RegionData dictionaries.
var regions: Array = []

## Loop behaviour.
var loop_mode: LoopMode = LoopMode.NONE

## Optional free-form notes.
var notes: String = ""


func _init(p_id: String = "", p_name: String = "Untitled") -> void:
	clip_id = p_id
	clip_name = p_name


## Convert to a serializable dictionary (deterministic key order).
func to_dict() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"clip_id": clip_id,
		"clip_name": clip_name,
		"duration": duration,
		"fps": fps,
		"loop_mode": loop_mode,
		"notes": notes,
		"markers": markers.duplicate(true),
		"regions": regions.duplicate(true),
		"tracks": tracks.duplicate(true)
	}


## Populate this instance from a serialized dictionary. Returns self.
func from_dict(d: Dictionary) -> AnimationClip:
	clip_id = d.get("clip_id", "")
	clip_name = d.get("clip_name", "Untitled")
	duration = float(d.get("duration", 1.0))
	fps = float(d.get("fps", 24.0))
	loop_mode = int(d.get("loop_mode", LoopMode.NONE)) as LoopMode
	notes = d.get("notes", "")
	markers = (d.get("markers", []) as Array).duplicate(true)
	regions = (d.get("regions", []) as Array).duplicate(true)
	tracks = (d.get("tracks", []) as Array).duplicate(true)
	return self


## Validate required fields. Returns Array of error strings.
func validate() -> Array:
	var errors: Array = []
	if clip_id.is_empty():
		errors.append("clip_id is required")
	if clip_name.is_empty():
		errors.append("clip_name is required")
	if duration <= 0.0:
		errors.append("duration must be > 0")
	if fps <= 0.0:
		errors.append("fps must be > 0")
	return errors


## Convert time in seconds to nearest frame number.
func time_to_frame(t: float) -> int:
	return int(round(t * fps))


## Convert frame number to time in seconds.
func frame_to_time(frame: int) -> float:
	return float(frame) / fps
