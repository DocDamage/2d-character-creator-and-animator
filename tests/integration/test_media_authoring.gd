# Integration tests for Phase 4 audio, lip-sync, and reference-media authoring data.
extends Node

const AudioSourceScript = preload("res://media/audio/audio_source_definition.gd")
const WaveformCacheScript = preload("res://media/audio/waveform_cache.gd")
const LipSyncImporterScript = preload("res://media/lip_sync/lip_sync_importer.gd")
const ReferenceScript = preload("res://media/references/reference_media_definition.gd")
const ReferenceLibraryScript = preload("res://media/references/reference_media_library.gd")
const MediaTimelineModelScript = preload("res://media/media_timeline_model.gd")
const MetadataInspectorScript = preload("res://gameplay_metadata/metadata_timeline_inspector.gd")
const ActionPointScript = preload("res://gameplay_metadata/action_points/action_point_definition.gd")
const ActionPointTrackScript = preload("res://gameplay_metadata/action_points/action_point_track.gd")
const AudioCueTrackScript = preload("res://gameplay_metadata/events/audio_cue_track.gd")
const VisemeTrackScript = preload("res://gameplay_metadata/events/viseme_track.gd")


func run_tests() -> int:
	var passes := 0
	passes += test_audio_waveform_and_lip_sync_import()
	passes += test_media_timeline_and_metadata_inspection()
	passes += test_reference_playhead_export_filter_and_repair()
	return passes


func test_audio_waveform_and_lip_sync_import() -> int:
	var audio = AudioSourceScript.new("voice", "Voice")
	audio.source_path = "res://tests/fixtures/audio/voice.wav"
	audio.duration_seconds = 1.0
	audio.sample_rate = 48000
	audio.channels = 1
	var waveform = WaveformCacheScript.new()
	waveform.audio_id = audio.audio_id
	waveform.build([-1.0, -0.2, 0.5, 1.0, 0.2, -0.8], 3)
	var imported: Dictionary = LipSyncImporterScript.parse_text("0.20\tAA\n0.10\tEE", "tsv")
	var track = VisemeTrackScript.new("mouth", "face", "viseme:mouth")
	var applied: Dictionary = LipSyncImporterScript.apply_to_track(track, imported, {"AA": "mouth_open", "EE": "mouth_wide"})
	if audio.validate().is_empty() and waveform.validate().is_empty() and waveform.peak_at_normalized_time(1.0) == [-0.8, 0.2] and applied.get("success", false) and applied.get("count", 0) == 2 and track.evaluate_viseme(0.15).get("viseme_id", "") == "EE":
		print("  PASS: MED-001 through MED-005 audio metadata, waveform cache, and timecoded lip-sync import")
		return 1
	printerr("  FAIL: audio waveform or lip-sync import failed")
	return 0


func test_media_timeline_and_metadata_inspection() -> int:
	var audio = AudioSourceScript.new("voice_model", "Voice Model")
	audio.source_path = "res://tests/fixtures/audio/model.wav"
	var audio_track = AudioCueTrackScript.new("audio", "hero", "audio:voice")
	var viseme_track = VisemeTrackScript.new("viseme", "hero", "mouth")
	var model = MediaTimelineModelScript.new()
	model.bind_tracks(audio_track, viseme_track)
	var added: Dictionary = model.add_audio_source(audio, [-0.5, 0.5], 2)
	var cue: Dictionary = model.add_sound_cue(0.2, "voice_1", audio.audio_id)
	model.import_lip_sync(LipSyncImporterScript, "0.2\tAA", "tsv", {"AA": "mouth_open"})
	var scrub: Dictionary = model.scrub_to(0.25, 0.0)
	var point = ActionPointScript.new("muzzle", "Muzzle")
	var point_track = ActionPointTrackScript.new("point", "hero", "point:muzzle")
	point_track.add_action_point_key(0.0, point, "p0")
	var inspector = MetadataInspectorScript.new()
	inspector.action_point_tracks = [point_track]
	inspector.audio_tracks = [audio_track]
	inspector.viseme_tracks = [viseme_track]
	var preview: Dictionary = inspector.evaluate(0.25, 0.0)
	if added.get("success", false) and cue.get("success", false) and scrub.get("audio_cues", []).size() == 1 and scrub.get("viseme", {}).get("viseme_id", "") == "AA" and model.validate().get("success", false) and preview.get("action_points", []).size() == 1 and preview.get("audio_cues", []).size() == 1:
		print("  PASS: GMD-001 through GMD-008 metadata inspector and media timeline scrub frame accurately")
		return 1
	printerr("  FAIL: media timeline or metadata inspector failed")
	return 0


func test_reference_playhead_export_filter_and_repair() -> int:
	var reference = ReferenceScript.new("acting", "Acting Reference")
	reference.kind = "video"
	reference.source_path = "res://project.godot"
	reference.offset_seconds = 1.0
	reference.duration_seconds = 2.0
	var missing = ReferenceScript.new("missing", "Missing Reference")
	missing.kind = "gif"
	missing.source_path = "res://missing.gif"
	var library = ReferenceLibraryScript.new()
	library.add_reference(reference)
	library.add_reference(missing)
	var active: Dictionary = library.evaluate_playhead(1.5)[0]
	var missing_count := library.find_missing().size()
	var repaired: bool = missing.repair_source("res://project.godot")
	reference.exclude_from_export = false
	var restored = ReferenceLibraryScript.new()
	var restore_errors: Array = restored.from_dict(library.to_dict(), ReferenceScript)
	if active.get("active", false) and missing_count == 1 and repaired and library.exportable_references().size() == 1 and restore_errors.is_empty() and restored.list_references().size() == 2:
		print("  PASS: MED-007 through MED-010 reference media synchronize, exclude, repair, and restore")
		return 1
	printerr("  FAIL: reference-media workflow failed")
	return 0
