# MediaTimelineModel -- Authoring bridge for audio cues, visemes, waveforms, and reference media.
class_name MediaTimelineModel
extends RefCounted

const WaveformScript = preload("res://media/audio/waveform_cache.gd")
const ReferenceLibraryScript = preload("res://media/references/reference_media_library.gd")

var audio_sources: Dictionary = {}
var waveforms: Dictionary = {}
var references = ReferenceLibraryScript.new()
var audio_track = null
var viseme_track = null
var current_time: float = 0.0


func bind_tracks(p_audio_track, p_viseme_track) -> void:
	audio_track = p_audio_track
	viseme_track = p_viseme_track


func add_audio_source(source, samples: Array = [], bucket_count: int = 256) -> Dictionary:
	if source == null or not source.validate().is_empty() or audio_sources.has(source.audio_id): return _failure("Choose a unique valid audio source.")
	audio_sources[source.audio_id] = source
	var waveform = WaveformScript.new()
	waveform.audio_id = source.audio_id
	waveform.build(samples, bucket_count)
	waveforms[source.audio_id] = waveform
	return {"success": true, "errors": [], "waveform": waveform.to_dict()}


func add_reference(reference) -> Dictionary:
	if references.add_reference(reference): return {"success": true, "errors": []}
	return _failure("Choose a unique valid reference-media source.")


func add_sound_cue(time: float, cue_id: String, audio_id: String, volume_db: float = 0.0, pan: float = 0.0) -> Dictionary:
	if audio_track == null or not audio_sources.has(audio_id): return _failure("Bind an audio track and registered source before adding a cue.")
	if time < 0.0 or cue_id.strip_edges().is_empty(): return _failure("Sound cues need a non-negative time and ID.")
	audio_track.add_cue(time, cue_id, audio_id, volume_db, pan)
	return {"success": true, "errors": []}


func import_lip_sync(importer, content: String, format_hint: String, mouth_map: Dictionary) -> Dictionary:
	if viseme_track == null: return _failure("Bind a viseme track before importing lip sync.")
	return importer.apply_to_track(viseme_track, importer.parse_text(content, format_hint), mouth_map)


func scrub_to(time: float, previous_time: float = -1.0) -> Dictionary:
	var from_time := current_time if previous_time < 0.0 else previous_time
	current_time = maxf(0.0, time)
	var cues: Array = audio_track.get_cues_between(from_time, current_time) if audio_track != null else []
	var viseme: Dictionary = viseme_track.evaluate_viseme(current_time) if viseme_track != null else {}
	return {"time": current_time, "audio_cues": cues, "viseme": viseme, "references": references.evaluate_playhead(current_time), "missing_references": references.find_missing()}


func export_data() -> Dictionary:
	return {"audio_sources": _source_data(), "waveforms": _waveform_data(), "references": references.exportable_references()}


func validate() -> Dictionary:
	var errors: Array = []
	for source in audio_sources.values(): errors.append_array(source.validate())
	for waveform in waveforms.values(): errors.append_array(waveform.validate())
	if audio_track != null: errors.append_array(audio_track.validate())
	if viseme_track != null: errors.append_array(viseme_track.validate())
	for reference in references.list_references(): errors.append_array(reference.validate(false))
	return {"success": errors.is_empty(), "errors": errors, "repair_actions": _repairs(errors)}


func _source_data() -> Array:
	var result: Array = []
	for source_id in audio_sources.keys(): result.append(audio_sources[source_id].to_dict())
	return result


func _waveform_data() -> Array:
	var result: Array = []
	for source_id in waveforms.keys(): result.append(waveforms[source_id].to_dict())
	return result


func _failure(message: String) -> Dictionary:
	return {"success": false, "errors": [message], "repair_actions": _repairs([message])}


func _repairs(errors: Array) -> Array:
	var result: Array = []
	for message in errors: result.append({"action": "repair_media", "message": str(message)})
	return result
