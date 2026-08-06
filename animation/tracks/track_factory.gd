# TrackFactory -- Restores specialized animation and gameplay track classes from data.
class_name TrackFactory
extends RefCounted

const ActionPointTrackScript = preload("res://gameplay_metadata/action_points/action_point_track.gd")
const EventTrackScript = preload("res://gameplay_metadata/events/animation_event_track.gd")
const CollisionTrackScript = preload("res://gameplay_metadata/hitboxes/collision_shape_track.gd")
const AudioCueTrackScript = preload("res://gameplay_metadata/events/audio_cue_track.gd")
const VisemeTrackScript = preload("res://gameplay_metadata/events/viseme_track.gd")
const ScriptParameterTrackScript = preload("res://gameplay_metadata/events/script_parameter_track.gd")
const TrackDefinitionScript = preload("res://animation/tracks/track_schema.gd")


static func from_dict(data: Dictionary):
	var type := int(data.get("track_type", TrackDefinition.TrackType.ATTRIBUTE))
	var track = _create(type)
	track.from_dict(data)
	if type == TrackDefinition.TrackType.HITBOX or type == TrackDefinition.TrackType.HURTBOX:
		track.collision_kind = "hitbox" if type == TrackDefinition.TrackType.HITBOX else "hurtbox"
	return track


static func _create(track_type: int):
	match track_type:
		TrackDefinition.TrackType.ACTION_POINT:
			return ActionPointTrackScript.new()
		TrackDefinition.TrackType.EVENT:
			return EventTrackScript.new()
		TrackDefinition.TrackType.HITBOX, TrackDefinition.TrackType.HURTBOX:
			return CollisionTrackScript.new()
		TrackDefinition.TrackType.AUDIO_CUE:
			return AudioCueTrackScript.new()
		TrackDefinition.TrackType.VISEME:
			return VisemeTrackScript.new()
		TrackDefinition.TrackType.SCRIPT_PARAMETER:
			return ScriptParameterTrackScript.new()
		_:
			return TrackDefinitionScript.new()
