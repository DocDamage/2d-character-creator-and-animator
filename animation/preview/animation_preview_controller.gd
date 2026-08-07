# AnimationPreviewController -- Owns disposable preview state and optional
# Auto Key routing.  It never evaluates into the saved rest pose.
class_name AnimationPreviewController
extends Node

const EvaluatorScript = preload("res://animation/preview/animation_preview_evaluator.gd")
const TrackDefinitionScript = preload("res://animation/tracks/track_schema.gd")

signal preview_evaluated(frame: Dictionary)
signal preview_log_entry(entry: Dictionary)
signal auto_key_changed(enabled: bool)
signal status_changed(message: String)

var _session = null
var _evaluator = EvaluatorScript.new()
var _active_clip_id := ""
var _appearance_preview_id := ""
var _current_time := 0.0
var _previous_time := -1.0
var _is_playing := false
var _auto_key := false
var _evaluated: Dictionary = {}
var _audio_players: Array = []


func bind_session(session) -> void:
	stop_preview()
	_session = session
	_active_clip_id = _session.get_active_animation_id() if _session != null and is_instance_valid(_session) else ""
	_appearance_preview_id = ""
	_current_time = 0.0
	_previous_time = -1.0
	_evaluate(false)


func set_clip(clip_id: String) -> void:
	_active_clip_id = clip_id
	_current_time = 0.0
	_previous_time = -1.0
	_evaluate(false)


func set_appearance_preview(appearance_id: String) -> void:
	_appearance_preview_id = appearance_id
	_previous_time = -1.0
	_evaluate(false)


func get_appearance_preview_id() -> String:
	return _appearance_preview_id


func set_time(time: float, is_playing: bool = false) -> void:
	_previous_time = _current_time
	_current_time = maxf(0.0, time)
	_is_playing = is_playing
	_evaluate(is_playing)


func stop_preview() -> void:
	_is_playing = false
	_previous_time = -1.0
	for player in _audio_players:
		if is_instance_valid(player): player.stop(); player.queue_free()
	_audio_players.clear()
	_evaluated = {}
	preview_evaluated.emit({})


func get_evaluated_frame() -> Dictionary:
	return _evaluated.duplicate(true)


func get_current_time() -> float:
	return _current_time


func set_auto_key(enabled: bool) -> void:
	if _auto_key == enabled: return
	_auto_key = enabled
	auto_key_changed.emit(_auto_key)
	status_changed.emit("Auto Key " + ("enabled" if _auto_key else "disabled"))


func is_auto_key_enabled() -> bool:
	return _auto_key


func get_keyed_state(object_id: String, property_path: String, time: float = -1.0) -> Dictionary:
	if _session == null or not is_instance_valid(_session): return {"keyed": false, "track_id": ""}
	var at_time: float = _current_time if time < 0.0 else time
	var clip: Dictionary = _session.get_animation_clip(_active_clip_id if not _active_clip_id.is_empty() else _session.get_active_animation_id())
	for raw_track in clip.get("tracks", []):
		var track: Dictionary = raw_track
		if str(track.get("object_id", "")) != object_id or str(track.get("property_path", "")) != property_path: continue
		for raw_key in track.get("keys", []):
			if absf(float((raw_key as Dictionary).get("time", -1.0)) - at_time) <= 0.0001:
				return {"keyed": true, "track_id": str(track.get("track_id", "")), "key_id": str((raw_key as Dictionary).get("key_id", ""))}
		return {"keyed": false, "track_id": str(track.get("track_id", ""))}
	return {"keyed": false, "track_id": ""}


func toggle_key(object_id: String, property_path: String, value: Variant, track_type: int = TrackDefinition.TrackType.ATTRIBUTE) -> Dictionary:
	if _session == null or not is_instance_valid(_session): return {"success": false, "errors": ["Open a project first."]}
	var clip_id: String = _active_clip_id if not _active_clip_id.is_empty() else _session.get_active_animation_id()
	if clip_id.is_empty(): return {"success": false, "errors": ["Create an animation clip first."]}
	var state: Dictionary = get_keyed_state(object_id, property_path)
	if bool(state.get("keyed", false)):
		var removed: bool = _session.delete_animation_key(clip_id, str(state.get("track_id", "")), str(state.get("key_id", "")))
		if removed: _evaluate(false)
		return {"success": removed, "removed": removed, "errors": [] if removed else ["The key could not be removed."]}
	return _set_or_add_key(clip_id, object_id, property_path, value, track_type)


func apply_property_edit(object_id: String, property_path: String, value: Variant, rest_pose_edit: Callable, track_type: int = TrackDefinition.TrackType.ATTRIBUTE) -> Dictionary:
	if _auto_key and _session != null and is_instance_valid(_session):
		var clip_id: String = _active_clip_id if not _active_clip_id.is_empty() else _session.get_active_animation_id()
		if not clip_id.is_empty():
			return _set_or_add_key(clip_id, object_id, property_path, value, track_type)
	if rest_pose_edit.is_valid():
		return {"success": bool(rest_pose_edit.call()), "rest_pose": true, "errors": []}
	return {"success": false, "errors": ["No rest-pose edit was supplied."]}


func _set_or_add_key(clip_id: String, object_id: String, property_path: String, value: Variant, track_type: int) -> Dictionary:
	var track_id := ""
	for raw_track in _session.get_animation_clip(clip_id).get("tracks", []):
		var track: Dictionary = raw_track
		if str(track.get("object_id", "")) == object_id and str(track.get("property_path", "")) == property_path:
			track_id = str(track.get("track_id", ""))
			break
	if track_id.is_empty():
		var added: Dictionary = _session.add_animation_track(clip_id, object_id, property_path, property_path.get_file().capitalize(), track_type)
		if not added.get("success", false): return added
		track_id = str(added.get("track_id", ""))
	var result: Dictionary = _session.set_or_add_animation_key(clip_id, track_id, _current_time, value, "Auto-Keyed " + property_path.get_file().capitalize())
	if result.get("success", false):
		_evaluate(false)
		status_changed.emit("Auto-keyed " + property_path)
	return result


func _evaluate(is_playing: bool) -> void:
	if _session == null or not is_instance_valid(_session):
		_evaluated = {}
		preview_evaluated.emit({})
		return
	var clip_id: String = _active_clip_id if not _active_clip_id.is_empty() else _session.get_active_animation_id()
	var clip: Dictionary = _session.get_animation_clip(clip_id)
	var base_layers: Array = _session.get_appearance_preview_layers(_appearance_preview_id) if not _appearance_preview_id.is_empty() else _session.get_preview_layers()
	_evaluated = _evaluator.evaluate(_session, clip, _current_time, _previous_time, is_playing, base_layers)
	for entry in _evaluated.get("preview_log", []): preview_log_entry.emit((entry as Dictionary).duplicate(true))
	if is_playing:
		for cue in _evaluated.get("audio_cues", []): _play_audio_cue(cue as Dictionary)
	preview_evaluated.emit(_evaluated.duplicate(true))


func _play_audio_cue(cue: Dictionary) -> void:
	if _session == null: return
	var asset: Dictionary = _session.asset_registry.get_asset(str(cue.get("audio_asset_id", "")))
	var path := str(asset.get("path", ""))
	if path.is_empty() or not FileAccess.file_exists(path):
		preview_log_entry.emit({"type": "audio_cue", "safe": true, "warning": "Audio cue asset is unavailable.", "cue": cue})
		return
	var stream = _load_audio_stream(path)
	if stream == null:
		preview_log_entry.emit({"type": "audio_cue", "safe": true, "warning": "Audio format could not be previewed.", "cue": cue})
		return
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.volume_db = float(cue.get("volume_db", 0.0))
	add_child(player)
	_audio_players.append(player)
	player.finished.connect(func(): if is_instance_valid(player): _audio_players.erase(player); player.queue_free())
	player.play()


func _load_audio_stream(path: String):
	match path.get_extension().to_lower():
		"wav": return AudioStreamWAV.load_from_file(path)
		"ogg": return AudioStreamOggVorbis.load_from_file(path)
		"mp3": return AudioStreamMP3.load_from_file(path)
	return null
