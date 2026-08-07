# LpcClipAuthoringModel -- Persists typed LPC clips and uses the shared hybrid evaluator/exporter.
class_name LpcClipAuthoringModel
extends RefCounted

const ClipSchemaScript = preload("res://lpc/animation/lpc_typed_clip_schema.gd")
const TrackSchemaScript = preload("res://lpc/animation/lpc_typed_track_schema.gd")
const EvaluatorScript = preload("res://lpc/animation/lpc_hybrid_clip_evaluator.gd")
const ExporterScript = preload("res://lpc/export/lpc_hybrid_exporter.gd")
const ProjectStoreScript = preload("res://lpc/project/lpc_project_store.gd")

signal changed(description: String)

var catalog: Dictionary = {}
var profile: Dictionary = {}
var manifest: Dictionary = {}
var project_path := ""


func bind_context(next_catalog: Dictionary, next_profile: Dictionary, next_manifest: Dictionary = {}, path: String = "") -> Dictionary:
	catalog = next_catalog.duplicate(true); profile = next_profile.duplicate(true); manifest = next_manifest.duplicate(true); project_path = path
	return {"success": not catalog.is_empty(), "errors": [] if not catalog.is_empty() else ["A validated LPC catalog is required."]}


func create_clip(name: String, options: Dictionary = {}) -> Dictionary:
	var clean := name.strip_edges(); if clean.is_empty(): return {"success": false, "errors": ["Give the LPC clip a name."]}
	var clip_id := str(options.get("clip_id", "")); if clip_id.is_empty(): clip_id = "lpc_" + clean.to_lower().replace(" ", "_") + "_" + str((profile.get("clips", []) as Array).size() + 1)
	if not ClipSchemaScript.find(profile, clip_id).is_empty(): return {"success": false, "errors": ["An LPC clip already uses ID '%s'." % clip_id]}
	var clip := ClipSchemaScript.create(clip_id, clean, options); _replace_clip(clip); changed.emit("Created LPC clip " + clean)
	return {"success": true, "errors": [], "clip": clip}


func add_track(clip_id: String, track_type: String, target_id: String, track_id: String = "") -> Dictionary:
	var clip := ClipSchemaScript.find(profile, clip_id); if clip.is_empty(): return {"success": false, "errors": ["Unknown LPC clip."]}
	var track := TrackSchemaScript.create(track_type, target_id, track_id); var errors := TrackSchemaScript.validate(track)
	if not errors.is_empty(): return {"success": false, "errors": errors}
	clip = ClipSchemaScript.add_track(clip, track); _replace_clip(clip); changed.emit("Added " + track_type + " track")
	return {"success": true, "errors": [], "track": track}


func set_key(clip_id: String, track_id: String, time: float, value: Variant, interpolation: String = "") -> Dictionary:
	var clip := ClipSchemaScript.find(profile, clip_id); if clip.is_empty(): return {"success": false, "errors": ["Unknown LPC clip."]}
	var found := false; var tracks: Array = (clip.get("tracks", []) as Array).duplicate(true)
	for index in range(tracks.size()):
		if tracks[index] is Dictionary and str((tracks[index] as Dictionary).get("track_id", "")) == track_id:
			tracks[index] = TrackSchemaScript.with_key(tracks[index], clampf(time, 0.0, float(clip.get("duration", 0.1))), value, interpolation); found = true
	if not found: return {"success": false, "errors": ["Unknown LPC track."]}
	clip["tracks"] = tracks; var errors := ClipSchemaScript.validate(clip)
	if not errors.is_empty(): return {"success": false, "errors": errors}
	_replace_clip(clip); changed.emit("Keyed " + track_id); return {"success": true, "errors": [], "clip": clip}


func preview(clip_id: String, time: float, previous_time: float = -1.0) -> Dictionary:
	var clip := ClipSchemaScript.find(profile, clip_id)
	return EvaluatorScript.evaluate(catalog, profile, clip, time, previous_time) if not clip.is_empty() else {"success": false, "errors": ["Unknown LPC clip."]}


func export_clip(clip_id: String, output_directory: String) -> Dictionary:
	var clip := ClipSchemaScript.find(profile, clip_id)
	return ExporterScript.export_clip(catalog, profile, clip, output_directory) if not clip.is_empty() else {"success": false, "errors": ["Unknown LPC clip."]}


func save() -> Dictionary:
	if project_path.is_empty() or manifest.is_empty(): return {"success": false, "errors": ["Bind an LPC project before saving clips."]}
	var saved := ProjectStoreScript.save(project_path, manifest, profile)
	if bool(saved.get("success", false)): manifest = saved.manifest.duplicate(true)
	return saved


func _replace_clip(clip: Dictionary) -> void:
	var clips: Array = (profile.get("clips", []) as Array).duplicate(true); var replaced := false
	for index in range(clips.size()):
		if clips[index] is Dictionary and str((clips[index] as Dictionary).get("clip_id", "")) == str(clip.get("clip_id", "")): clips[index] = clip.duplicate(true); replaced = true
	if not replaced: clips.append(clip.duplicate(true))
	clips.sort_custom(func(a: Dictionary, b: Dictionary): return str(a.get("clip_id", "")) < str(b.get("clip_id", ""))); profile["clips"] = clips
