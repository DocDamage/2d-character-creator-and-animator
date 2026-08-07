# LpcHybridExporter -- Writes replayable hybrid frames and their typed-clip/render manifests.
class_name LpcHybridExporter
extends RefCounted

const EvaluatorScript = preload("res://lpc/animation/lpc_hybrid_clip_evaluator.gd")


static func export_clip(catalog: Dictionary, profile: Dictionary, clip: Dictionary, output_directory: String) -> Dictionary:
	var fps := maxf(1.0, float(clip.get("fps", 10.0))); var frame_count := maxi(1, ceili(float(clip.get("duration", 0.1)) * fps))
	var absolute := ProjectSettings.globalize_path(output_directory) if output_directory.begins_with("user://") or output_directory.begins_with("res://") else output_directory
	if DirAccess.make_dir_recursive_absolute(absolute) != OK: return {"success": false, "errors": ["Could not create the hybrid export folder."]}
	var frames: Array = []; var previous := -1.0; var credits: Dictionary = {}
	for index in range(frame_count):
		var time := float(index) / fps; var evaluated := EvaluatorScript.evaluate(catalog, profile, clip, time, previous)
		if not bool(evaluated.get("success", false)): return {"success": false, "errors": evaluated.get("errors", []) + ["Hybrid export stopped at frame %d." % index], "warnings": evaluated.get("warnings", [])}
		var filename := "%s_%04d.png" % [str(clip.get("clip_id", "clip")), index]; var path := output_directory.path_join(filename)
		if (evaluated.image as Image).save_png(path) != OK: return {"success": false, "errors": ["Could not write hybrid frame '%s'." % path]}
		frames.append({"index": index, "time": time, "file": filename, "output_hash": evaluated.get("output_hash", ""), "snapshot_hash": (evaluated.get("snapshot", {}) as Dictionary).get("snapshot_hash", ""), "events": evaluated.get("events", []), "warnings": evaluated.get("warnings", [])})
		credits = evaluated.get("credits", {}); previous = time
	var manifest := {"format": "lpc_hybrid_frames", "clip": clip.duplicate(true), "frames": frames, "source_lock": profile.get("source_lock", {}), "catalog_signature": catalog.get("catalog_signature", ""), "credits": credits}
	var manifest_path := output_directory.path_join("lpc_hybrid_manifest.json"); var file := FileAccess.open(manifest_path, FileAccess.WRITE)
	if file == null: return {"success": false, "errors": ["Could not write the hybrid export manifest."]}
	file.store_string(JSON.stringify(manifest, "\t")); file.close()
	return {"success": true, "errors": [], "manifest": manifest_path, "frame_count": frame_count, "frames": frames}
