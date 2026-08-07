# LpcNativeExporter -- Writes verified native LPC frames and a source/credit manifest.
class_name LpcNativeExporter
extends RefCounted

const EvaluatorScript = preload("res://lpc/animation/lpc_native_clip_evaluator.gd")


static func export_clip(catalog: Dictionary, profile: Dictionary, animation_id: String, direction_id: String, output_directory: String, options: Dictionary = {}) -> Dictionary:
	var frame_count := int(options.get("frame_count", EvaluatorScript.frame_count(catalog, profile, animation_id, direction_id)))
	var fps := maxf(1.0, float(options.get("fps", 10.0)))
	if frame_count <= 0:
		return {"success": false, "errors": ["No fully supported native frames are available for '%s'." % animation_id]}
	var absolute := ProjectSettings.globalize_path(output_directory) if output_directory.begins_with("user://") or output_directory.begins_with("res://") else output_directory
	if DirAccess.make_dir_recursive_absolute(absolute) != OK:
		return {"success": false, "errors": ["Could not create native export folder."]}
	var frames: Array = []
	var credits: Dictionary = {}
	for index in range(frame_count):
		var evaluated := EvaluatorScript.evaluate(catalog, profile, animation_id, direction_id, float(index) / fps)
		if not bool(evaluated.get("success", false)):
			return {"success": false, "errors": evaluated.get("errors", []) + ["Native export stopped at frame %d." % index], "conflicts": evaluated.get("conflicts", [])}
		var filename := "%s_%s_%04d.png" % [animation_id, direction_id, index]
		var path := output_directory.path_join(filename)
		if (evaluated.image as Image).save_png(path) != OK:
			return {"success": false, "errors": ["Could not write %s." % path]}
		frames.append({"index": index, "file": filename, "duration": 1.0 / fps, "output_hash": str(evaluated.get("output_hash", "")), "snapshot_hash": str((evaluated.get("snapshot", {}) as Dictionary).get("snapshot_hash", "")), "layers": evaluated.get("layers", [])})
		credits = evaluated.get("credits", {})
	var manifest := {"format": "lpc_native_frames", "animation_id": animation_id, "direction_id": direction_id, "fps": fps, "frames": frames, "credits": credits, "source_lock": profile.get("source_lock", {}), "catalog_signature": catalog.get("catalog_signature", "")}
	var manifest_path := output_directory.path_join("lpc_native_manifest.json")
	var file := FileAccess.open(manifest_path, FileAccess.WRITE)
	if file == null:
		return {"success": false, "errors": ["Could not write the native export manifest."]}
	file.store_string(JSON.stringify(manifest, "\t")); file.close()
	return {"success": true, "errors": [], "directory": output_directory, "manifest": manifest_path, "frame_count": frames.size(), "frames": frames}
