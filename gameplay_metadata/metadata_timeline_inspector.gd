# MetadataTimelineInspector -- Frame-accurate authoring preview and diagnostics for gameplay tracks.
class_name MetadataTimelineInspector
extends RefCounted

var action_point_tracks: Array = []
var collision_tracks: Array = []
var event_tracks: Array = []
var audio_tracks: Array = []
var viseme_tracks: Array = []


func evaluate(time: float, previous_time: float = 0.0) -> Dictionary:
	var action_points: Array = []
	var collisions: Array = []
	var events: Array = []
	var audio_cues: Array = []
	var visemes: Array = []
	for track in action_point_tracks: action_points.append({"track_id": track.track_id, "value": track.evaluate_action_point(time)})
	for track in collision_tracks: collisions.append({"track_id": track.track_id, "kind": track.collision_kind, "shapes": track.evaluate_shapes(time)})
	for track in event_tracks: events.append_array(track.get_events_between(previous_time, time))
	for track in audio_tracks: audio_cues.append_array(track.get_cues_between(previous_time, time))
	for track in viseme_tracks: visemes.append({"track_id": track.track_id, "value": track.evaluate_viseme(time)})
	return {"time": time, "action_points": action_points, "collisions": collisions, "events": events, "audio_cues": audio_cues, "visemes": visemes}


func validate() -> Dictionary:
	var errors: Array = []
	for track in _all_tracks(): errors.append_array(track.validate())
	return {"success": errors.is_empty(), "errors": errors, "repair_actions": _repairs(errors)}


func _all_tracks() -> Array:
	var tracks: Array = []
	for group in [action_point_tracks, collision_tracks, event_tracks, audio_tracks, viseme_tracks]: tracks.append_array(group)
	return tracks


func _repairs(errors: Array) -> Array:
	var repairs: Array = []
	for message in errors: repairs.append({"action": "open_track_and_repair", "message": str(message)})
	return repairs
