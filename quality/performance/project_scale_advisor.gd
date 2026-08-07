# ProjectScaleAdvisor -- Deterministic project-size guidance for artists.
#
# It is deliberately advisory: a large imported project remains valid.  The
# report makes the trade-offs visible before the artist commits to a slow live
# preview or a very large review export.
class_name ProjectScaleAdvisor
extends RefCounted

const LAYER_WARNING := 120
const TRACK_WARNING := 300
const KEY_WARNING := 10000
const APPEARANCE_WARNING := 64
const REVIEW_FRAME_WARNING := 2500
const SOURCE_BYTES_WARNING := 512 * 1024 * 1024
const DECODED_BYTES_WARNING := 1024 * 1024 * 1024
const CANVAS_PIXELS_WARNING := 16 * 1024 * 1024


func analyze(session, _options: Dictionary = {}) -> Dictionary:
	if session == null or not is_instance_valid(session) or session.model == null:
		return {"success": false, "grade": "unavailable", "issues": [], "recommendations": ["Open a project to inspect its scale."], "counts": {}}
	var assets: Array = session.asset_registry.list_assets()
	var layer_count: int = int(session.get_layer_entries().size())
	var source_bytes: int = 0
	var decoded_bytes: int = 0
	for raw_asset in assets:
		var asset: Dictionary = raw_asset
		var path := str(asset.get("path", ""))
		if not path.is_empty() and FileAccess.file_exists(path):
			source_bytes += FileAccess.get_file_as_bytes(path).size()
		decoded_bytes += maxi(0, int(asset.get("width", 0))) * maxi(0, int(asset.get("height", 0))) * 4
	var clips: Array = session.get_animation_clips()
	var track_count: int = 0
	var key_count: int = 0
	var base_frames: int = 0
	for raw_clip in clips:
		var clip: Dictionary = raw_clip
		var tracks: Array = clip.get("tracks", [])
		track_count += tracks.size()
		for raw_track in tracks:
			key_count += ((raw_track as Dictionary).get("keys", []) as Array).size()
		base_frames += int(ceil(maxf(0.01, float(clip.get("duration", 1.0))) * maxf(1.0, float(clip.get("fps", 24.0))))) + 1
	var appearances: int = maxi(1, int(session.get_appearance_sets().size()))
	var canvas: Dictionary = session.get_canvas_settings()
	var canvas_pixels: int = int(canvas.get("width", 0)) * int(canvas.get("height", 0))
	var review_frames: int = base_frames * appearances
	var counts := {
		"assets": assets.size(),
		"layers": layer_count,
		"clips": clips.size(),
		"tracks": track_count,
		"keys": key_count,
		"appearance_sets": appearances,
		"review_frames": review_frames,
		"source_bytes": source_bytes,
		"decoded_bytes": decoded_bytes,
		"canvas_pixels": canvas_pixels,
	}
	var issues: Array = []
	if layer_count > LAYER_WARNING:
		issues.append(_issue("many_layers", "warning", "%d layers are assembled. Consider grouping optional details or using appearance sets for alternatives." % layer_count, {"count": layer_count, "threshold": LAYER_WARNING}))
	if track_count > TRACK_WARNING:
		issues.append(_issue("many_tracks", "warning", "%d tracks can make timeline editing and review evaluation slower." % track_count, {"count": track_count, "threshold": TRACK_WARNING}))
	if key_count > KEY_WARNING:
		issues.append(_issue("many_keys", "warning", "%d keyframes can make bulk edits and review renders slower." % key_count, {"count": key_count, "threshold": KEY_WARNING}))
	if appearances > APPEARANCE_WARNING:
		issues.append(_issue("many_appearances", "warning", "%d Appearance Sets will multiply every review export by clip count." % appearances, {"count": appearances, "threshold": APPEARANCE_WARNING}))
	if review_frames > REVIEW_FRAME_WARNING:
		issues.append(_issue("large_review_job", "warning", "This review package will render %d frames. Use the estimate and leave the app open until it finishes." % review_frames, {"count": review_frames, "threshold": REVIEW_FRAME_WARNING}))
	if source_bytes > SOURCE_BYTES_WARNING:
		issues.append(_issue("large_source_library", "warning", "Imported source files total %s. Saves, portable copies, and snapshots may take longer." % _format_bytes(source_bytes), {"bytes": source_bytes, "threshold": SOURCE_BYTES_WARNING}))
	if decoded_bytes > DECODED_BYTES_WARNING:
		issues.append(_issue("large_decoded_memory", "warning", "Loaded artwork can require about %s of decoded texture memory." % _format_bytes(decoded_bytes), {"bytes": decoded_bytes, "threshold": DECODED_BYTES_WARNING}))
	if canvas_pixels > CANVAS_PIXELS_WARNING:
		issues.append(_issue("large_canvas", "warning", "The %d × %d canvas is high-resolution; preview and contact sheets will use more memory." % [int(canvas.get("width", 0)), int(canvas.get("height", 0))], {"pixels": canvas_pixels, "threshold": CANVAS_PIXELS_WARNING}))
	var recommendations: Array = []
	if issues.is_empty():
		recommendations.append("Project scale looks comfortable for live editing and review export.")
	else:
		recommendations.append("Use named snapshots before large simplification or consolidation passes.")
		if review_frames > REVIEW_FRAME_WARNING:
			recommendations.append("Export a smaller approval package first, then run the full clip × appearance handoff when approved.")
		if source_bytes > SOURCE_BYTES_WARNING or decoded_bytes > DECODED_BYTES_WARNING:
			recommendations.append("Keep original masters outside the project and import appropriately sized production copies.")
	return {"success": true, "grade": "advisory" if not issues.is_empty() else "healthy", "issues": issues, "warnings": issues.duplicate(true), "recommendations": recommendations, "counts": counts}


static func format_summary(report: Dictionary) -> String:
	if not bool(report.get("success", false)):
		return "Project scale is unavailable."
	var counts: Dictionary = report.get("counts", {}) as Dictionary
	var issues: Array = report.get("issues", []) as Array
	return "%d layers · %d clips · %d tracks · %d keys · %d review frames%s" % [int(counts.get("layers", 0)), int(counts.get("clips", 0)), int(counts.get("tracks", 0)), int(counts.get("keys", 0)), int(counts.get("review_frames", 0)), " · %d advisory issue%s" % [issues.size(), "s" if issues.size() != 1 else ""] if not issues.is_empty() else " · scale looks healthy"]


## Lets CI exercise large-workload thresholds without creating giant textures
## or allocating a synthetic project document.  Production reports still come
## from analyze(session), which measures the real imported assets.
static func analyze_synthetic(counts: Dictionary) -> Dictionary:
	var issues: Array = []
	var layers := int(counts.get("layers", 0))
	var tracks := int(counts.get("tracks", 0))
	var keys := int(counts.get("keys", 0))
	var appearances := int(counts.get("appearance_sets", 0))
	var review_frames := int(counts.get("review_frames", 0))
	var source_bytes := int(counts.get("source_bytes", 0))
	if layers > LAYER_WARNING: issues.append({"id": "many_layers", "severity": "warning", "message": "%d synthetic layers exceed the live-edit advisory threshold." % layers})
	if tracks > TRACK_WARNING: issues.append({"id": "many_tracks", "severity": "warning", "message": "%d synthetic tracks exceed the timeline advisory threshold." % tracks})
	if keys > KEY_WARNING: issues.append({"id": "many_keys", "severity": "warning", "message": "%d synthetic keyframes exceed the bulk-edit advisory threshold." % keys})
	if appearances > APPEARANCE_WARNING: issues.append({"id": "many_appearances", "severity": "warning", "message": "%d synthetic Appearance Sets exceed the normal review-combination threshold." % appearances})
	if review_frames > REVIEW_FRAME_WARNING: issues.append({"id": "large_review_job", "severity": "warning", "message": "%d synthetic review frames exceed the handoff advisory threshold." % review_frames})
	if source_bytes > SOURCE_BYTES_WARNING: issues.append({"id": "large_source_library", "severity": "warning", "message": "Synthetic source bytes exceed the portable-copy advisory threshold."})
	return {"success": true, "grade": "advisory" if not issues.is_empty() else "healthy", "issues": issues, "warnings": issues.duplicate(true), "counts": counts.duplicate(true)}


func _issue(id: String, severity: String, message: String, context: Dictionary = {}) -> Dictionary:
	var issue := {"id": id, "severity": severity, "message": message, "target": "performance"}
	for key in context:
		issue[key] = context[key]
	return issue


func _format_bytes(bytes: int) -> String:
	if bytes < 1024 * 1024:
		return "%d KB" % maxi(1, bytes / 1024)
	if bytes < 1024 * 1024 * 1024:
		return "%.1f MB" % (float(bytes) / (1024.0 * 1024.0))
	return "%.2f GB" % (float(bytes) / (1024.0 * 1024.0 * 1024.0))
