# ReviewPackageExporter -- Creates an approval-ready folder and ZIP from every
# saved clip × Appearance Set.  It is import-only: all pixels come from the
# evaluated registered artwork in the active document.
class_name ReviewPackageExporter
extends RefCounted

const EvaluatorScript = preload("res://animation/preview/animation_preview_evaluator.gd")
const RendererScript = preload("res://export/review/character_raster_renderer.gd")
const GifExporterScript = preload("res://export/gif/gif_exporter.gd")
const VideoExporterScript = preload("res://export/video/video_exporter.gd")
const TrackDefinitionScript = preload("res://animation/tracks/track_schema.gd")


func get_estimate(session) -> Dictionary:
	if session == null or not is_instance_valid(session): return {"items": 0, "frames": 0, "estimated_bytes": 0, "estimated_seconds": 0.0}
	var clips: Array = session.get_animation_clips()
	var appearances: Array = session.get_appearance_sets()
	var appearance_count: int = max(1, appearances.size())
	var frames: int = 0
	for raw_clip in clips:
		var clip: Dictionary = raw_clip
		frames += int(ceil(float(clip.get("duration", 1.0)) * maxf(1.0, float(clip.get("fps", 24.0))))) + 1
	var canvas: Dictionary = session.get_canvas_settings()
	var pixels := int(canvas.get("width", 512)) * int(canvas.get("height", 512))
	return {"items": clips.size() * appearance_count, "frames": frames * appearance_count, "estimated_bytes": frames * appearance_count * pixels * 2, "estimated_seconds": float(frames * appearance_count) * 0.04}


func export_package(session, output_folder: String = "", options: Dictionary = {}) -> Dictionary:
	if session == null or not is_instance_valid(session): return _failure("Open a character project before creating a review package.")
	var validation: Dictionary = session.get_readiness_report({"require_clips": true, "check_mp4": true})
	if not bool(validation.get("can_export", false)):
		return {"success": false, "errors": ["Resolve blocking readiness issues before export."], "validation": validation}
	if not (validation.get("warnings", []) as Array).is_empty() and not bool(options.get("warnings_confirmed", false)):
		return {"success": false, "requires_warning_confirmation": true, "errors": ["Review the readiness warnings and confirm export."], "validation": validation}
	var destination: String = _choose_destination(session, output_folder)
	if DirAccess.make_dir_recursive_absolute(_absolute(destination)) != OK:
		return _failure("Could not create the review package folder.")
	var background: String = str(options.get("background", "neutral"))
	if background not in ["neutral", "checkerboard", "transparent"]: background = "neutral"
	var include_mp4: bool = bool(options.get("include_mp4", true))
	var video_exporter: RefCounted = VideoExporterScript.new()
	var ffmpeg_available: bool = video_exporter.is_available()
	var warnings: Array = (validation.get("warnings", []) as Array).duplicate(true)
	if include_mp4 and not ffmpeg_available: warnings.append({"id": "ffmpeg_unavailable", "severity": "warning", "message": "MP4 was skipped because ffmpeg is unavailable."})
	var clips: Array = session.get_animation_clips()
	var appearances: Array = session.get_appearance_sets()
	if appearances.is_empty(): appearances = [{"appearance_id": "current", "name": "Current assembly", "kind": "baseline"}]
	var estimate: Dictionary = get_estimate(session)
	var manifest: Dictionary = {"status": "incomplete", "created_at": Time.get_unix_time_from_system(), "background": background, "background_fallback_for_gif_mp4": "neutral" if background == "transparent" else background, "estimate": estimate, "items": [], "warnings": warnings.duplicate(true)}
	_write_json(destination.path_join("incomplete_manifest.json"), manifest)
	var renderer: RefCounted = RendererScript.new()
	var evaluator: RefCounted = EvaluatorScript.new()
	var gif_exporter: RefCounted = GifExporterScript.new()
	var total_frames: int = maxi(1, int(estimate.get("frames", 1)))
	var completed_frames: int = 0
	var cancelled: bool = false
	for raw_appearance in appearances:
		var appearance: Dictionary = raw_appearance
		var appearance_id: String = _safe_name(str(appearance.get("appearance_id", "current")))
		var appearance_layers: Array = session.get_appearance_preview_layers(str(appearance.get("appearance_id", ""))) if str(appearance.get("appearance_id", "")) != "current" else session.get_preview_layers()
		for raw_clip in clips:
			if _is_cancelled(options): cancelled = true; break
			var clip: Dictionary = raw_clip
			var clip_id: String = _safe_name(str(clip.get("clip_id", "clip")))
			var item_folder: String = destination.path_join("items").path_join(appearance_id).path_join(clip_id)
			var frame_folder: String = item_folder.path_join("frames")
			var video_frame_folder: String = item_folder.path_join("video_frames")
			DirAccess.make_dir_recursive_absolute(_absolute(frame_folder))
			if background == "transparent": DirAccess.make_dir_recursive_absolute(_absolute(video_frame_folder))
			var fps: float = maxf(1.0, float(clip.get("fps", 24.0)))
			var frame_count: int = int(ceil(float(clip.get("duration", 1.0)) * fps)) + 1
			var gif_frames: Array = []
			var contact_frames: Array = []
			for frame_index in range(frame_count):
				if _is_cancelled(options): cancelled = true; break
				var time: float = minf(float(clip.get("duration", 1.0)), float(frame_index) / fps)
				var evaluated: Dictionary = evaluator.evaluate(session, clip, time, -1.0, false, appearance_layers)
				var png_image: Image = renderer.render_layers(evaluated.get("layers", []), session.get_canvas_settings(), background)
				var media_image: Image = png_image if background != "transparent" else renderer.render_layers(evaluated.get("layers", []), session.get_canvas_settings(), "neutral")
				var png_path: String = frame_folder.path_join("frame_%05d.png" % frame_index)
				if png_image.save_png(_absolute(png_path)) != OK:
					warnings.append({"id": "frame_write_failed", "severity": "warning", "message": "Could not save " + png_path})
				if background == "transparent": media_image.save_png(_absolute(video_frame_folder.path_join("frame_%05d.png" % frame_index)))
				gif_frames.append({"image": media_image})
				contact_frames.append(png_image)
				completed_frames += 1
				_notify_progress(options, completed_frames, total_frames, str(appearance.get("name", appearance_id)) + " · " + str(clip.get("clip_name", clip_id)))
			if cancelled: break
			var gif_report: Dictionary = gif_exporter.export_frames(gif_frames, item_folder.path_join("preview.gif"), fps, 0)
			if not gif_report.get("success", false): warnings.append({"id": "gif_failed", "severity": "warning", "message": str(gif_report.get("errors", ["GIF encoding failed."])[0])})
			var contact_path: String = item_folder.path_join("contact_sheet.png")
			var contact: Image = _make_contact_sheet(contact_frames)
			if contact != null: contact.save_png(_absolute(contact_path))
			var cue_timing := _cue_timing(session, clip)
			var timing_path: String = item_folder.path_join("timing.json")
			_write_json(timing_path, cue_timing)
			var item_data := {"appearance_id": str(appearance.get("appearance_id", "current")), "appearance_name": str(appearance.get("name", appearance_id)), "clip_id": str(clip.get("clip_id", clip_id)), "clip_name": str(clip.get("clip_name", clip_id)), "fps": fps, "frame_count": frame_count, "folder": item_folder, "gif": item_folder.path_join("preview.gif"), "contact_sheet": contact_path, "contact_sheet_size": [contact.get_width(), contact.get_height()] if contact != null else [0, 0], "timing": timing_path}
			if include_mp4 and ffmpeg_available:
				var pattern := (video_frame_folder if background == "transparent" else frame_folder).path_join("frame_%05d.png")
				var mp4_report: Dictionary = video_exporter.export_sequence_with_audio(pattern, item_folder.path_join("preview.mp4"), fps, cue_timing.get("audio_cues", []))
				if mp4_report.get("success", false): item_data["mp4"] = item_folder.path_join("preview.mp4")
				else: warnings.append({"id": "mp4_failed", "severity": "warning", "message": str(mp4_report.get("errors", ["MP4 export failed."])[0]), "item": item_data})
			manifest.items.append(item_data)
		if cancelled: break
	if cancelled:
		manifest["status"] = "cancelled"
		manifest["completed_frames"] = completed_frames
		manifest["warnings"] = warnings
		_write_json(destination.path_join("incomplete_manifest.json"), manifest)
		return {"success": false, "cancelled": true, "errors": [], "folder": destination, "manifest": destination.path_join("incomplete_manifest.json"), "completed_frames": completed_frames}
	manifest["status"] = "complete"
	manifest["completed_frames"] = completed_frames
	manifest["warnings"] = warnings
	manifest["validation"] = validation
	_write_json(destination.path_join("project_metadata.json"), session.manifest.duplicate(true))
	_write_json(destination.path_join("validation_report.json"), validation)
	_write_json(destination.path_join("review_manifest.json"), manifest)
	_write_text(destination.path_join("README.txt"), _readme(session, manifest))
	DirAccess.remove_absolute(_absolute(destination.path_join("incomplete_manifest.json")))
	var zip_path: String = destination.get_base_dir().path_join(destination.get_file() + ".zip")
	var zip_report: Dictionary = _zip_folder(destination, zip_path)
	if not zip_report.get("success", false): warnings.append({"id": "zip_failed", "severity": "warning", "message": str(zip_report.get("errors", ["ZIP creation failed."])[0])})
	_notify_progress(options, total_frames, total_frames, "Review package complete")
	return {"success": true, "errors": [], "folder": destination, "zip": zip_path if zip_report.get("success", false) else "", "manifest": destination.path_join("review_manifest.json"), "warnings": warnings, "estimate": estimate, "items": manifest.items}


func _cue_timing(session, clip: Dictionary) -> Dictionary:
	var result := {"audio_cues": [], "events": [], "script_parameters": [], "visemes": []}
	for raw_track in clip.get("tracks", []):
		var track: Dictionary = raw_track
		var type: int = int(track.get("track_type", TrackDefinition.TrackType.ATTRIBUTE))
		for raw_key in track.get("keys", []):
			var key: Dictionary = raw_key
			var value: Variant = key.get("value", {})
			if type == TrackDefinition.TrackType.AUDIO_CUE and value is Dictionary:
				var cue: Dictionary = (value as Dictionary).duplicate(true)
				cue["time"] = float(key.get("time", 0.0))
				cue["path"] = str(session.asset_registry.get_asset(str(cue.get("audio_asset_id", ""))).get("path", ""))
				result.audio_cues.append(cue)
			elif type == TrackDefinition.TrackType.EVENT:
				result.events.append({"time": float(key.get("time", 0.0)), "value": value})
			elif type == TrackDefinition.TrackType.SCRIPT_PARAMETER:
				result.script_parameters.append({"time": float(key.get("time", 0.0)), "parameter": str(track.get("parameter_name", track.get("property_path", ""))), "value": value, "safe": true})
			elif type == TrackDefinition.TrackType.VISEME:
				result.visemes.append({"time": float(key.get("time", 0.0)), "value": value})
	return result


func _make_contact_sheet(frames: Array) -> Image:
	if frames.is_empty(): return null
	var first: Image = frames[0] as Image
	if first == null or first.is_empty(): return null
	var thumb_size: Vector2i = Vector2i(maxi(1, mini(256, first.get_width())), maxi(1, mini(256, first.get_height())))
	var columns: int = mini(6, frames.size())
	var rows: int = int(ceil(float(frames.size()) / float(columns)))
	var sheet: Image = Image.create(thumb_size.x * columns, thumb_size.y * rows, false, Image.FORMAT_RGBA8)
	sheet.fill(Color("20242d"))
	for index in range(frames.size()):
		var frame: Image = frames[index] as Image
		var thumb: Image = frame.duplicate()
		thumb.resize(thumb_size.x, thumb_size.y, Image.INTERPOLATE_NEAREST)
		sheet.blit_rect(thumb, Rect2i(Vector2i.ZERO, thumb.get_size()), Vector2i((index % columns) * thumb_size.x, int(index / columns) * thumb_size.y))
	return sheet


func _choose_destination(session, requested: String) -> String:
	if not requested.strip_edges().is_empty(): return requested.strip_edges()
	var root: String = session.project_path.get_base_dir().path_join("reviews")
	var base: String = "%s_%d" % [_safe_name(session.project_path.get_file().get_basename()), Time.get_unix_time_from_system()]
	var destination: String = root.path_join(base)
	var suffix: int = 2
	while DirAccess.dir_exists_absolute(_absolute(destination)):
		destination = root.path_join(base + "_%d" % suffix)
		suffix += 1
	return destination


func _zip_folder(folder: String, zip_path: String) -> Dictionary:
	var zip: ZIPPacker = ZIPPacker.new()
	if zip.open(_absolute(zip_path)) != OK: return _failure("Could not create the review ZIP.")
	var files: Array = []
	_collect_files(folder, files)
	for path in files:
		var archive_path: String = str(path).trim_prefix(folder.trim_suffix("/") + "/")
		var file := FileAccess.open(_absolute(path), FileAccess.READ)
		if file == null or zip.start_file(archive_path) != OK:
			if file != null: file.close()
			zip.close()
			return _failure("Could not add review file to ZIP: " + archive_path)
		var error: Error = zip.write_file(file.get_buffer(file.get_length()))
		file.close()
		if error != OK:
			zip.close()
			return _failure("Could not write review file to ZIP: " + archive_path)
	zip.close()
	return {"success": FileAccess.file_exists(_absolute(zip_path)), "errors": [], "path": zip_path}


func _collect_files(folder: String, output: Array) -> void:
	var directory := DirAccess.open(_absolute(folder))
	if directory == null: return
	directory.list_dir_begin()
	var entry := directory.get_next()
	while not entry.is_empty():
		if entry != "." and entry != "..":
			var path := folder.path_join(entry)
			if directory.current_is_dir(): _collect_files(path, output)
			else: output.append(path)
		entry = directory.get_next()
	directory.list_dir_end()


func _is_cancelled(options: Dictionary) -> bool:
	var callback: Callable = options.get("cancel_callable", Callable())
	return callback.is_valid() and bool(callback.call())


func _notify_progress(options: Dictionary, completed: int, total: int, label: String) -> void:
	var callback: Callable = options.get("progress_callable", Callable())
	if callback.is_valid(): callback.call({"completed": completed, "total": total, "fraction": float(completed) / maxf(1.0, float(total)), "label": label})


func _write_json(path: String, data: Dictionary) -> bool:
	var file := FileAccess.open(_absolute(path), FileAccess.WRITE)
	if file == null: return false
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	return true


func _write_text(path: String, text: String) -> bool:
	var file := FileAccess.open(_absolute(path), FileAccess.WRITE)
	if file == null: return false
	file.store_string(text)
	file.close()
	return true


func _readme(session, manifest: Dictionary) -> String:
	return "# Review package\n\nProject: %s\n\nThis folder was rendered from artist-imported assets only. It contains one GIF/contact sheet (and MP4 when available) for each saved clip × Appearance Set, plus validation and timing metadata.\n\nBackground: %s\nItems: %d\n" % [str(session.manifest.get("project_name", "Character Project")), str(manifest.get("background", "neutral")), (manifest.get("items", []) as Array).size()]


func _absolute(path: String) -> String:
	return ProjectSettings.globalize_path(path) if path.begins_with("res://") or path.begins_with("user://") else path


func _safe_name(value: String) -> String:
	var clean := value.validate_filename().replace(" ", "_")
	return clean if not clean.is_empty() else "item"


func _failure(message: String) -> Dictionary:
	return {"success": false, "errors": [message]}
