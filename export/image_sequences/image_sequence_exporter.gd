# ImageSequenceExporter -- Writes lossless PNG or WebP image sequences and a manifest.
class_name ImageSequenceExporter
extends RefCounted


func export_frames(frames: Array, output_directory: String, format: String = "png", fps: float = 24.0) -> Dictionary:
	var ext := format.to_lower()
	if ext not in ["png", "webp"]:
		return {"success": false, "errors": ["format must be png or webp"]}
	var absolute := ProjectSettings.globalize_path(output_directory)
	if DirAccess.make_dir_recursive_absolute(absolute) != OK:
		return {"success": false, "errors": ["cannot create output directory"]}
	var manifest_frames: Array = []
	for index in range(frames.size()):
		var frame: Dictionary = frames[index]
		var image: Image = frame.get("image")
		if image == null:
			return {"success": false, "errors": ["frame %d has no image" % index]}
		var file_name := "%04d.%s" % [index, ext]
		var path := output_directory.path_join(file_name)
		var error := image.save_png(path) if ext == "png" else image.save_webp(path)
		if error != OK:
			return {"success": false, "errors": ["cannot save " + path]}
		manifest_frames.append({"index": index, "id": str(frame.get("id", index)), "file": file_name, "duration": 1.0 / maxf(fps, 0.001)})
	var manifest_path := output_directory.path_join("manifest.json")
	var manifest := FileAccess.open(manifest_path, FileAccess.WRITE)
	if manifest == null:
		return {"success": false, "errors": ["cannot save image-sequence manifest"]}
	manifest.store_string(JSON.stringify({"format": "image_sequence", "fps": fps, "frames": manifest_frames}, "\t"))
	manifest.close()
	return {"success": true, "directory": output_directory, "manifest": manifest_path, "frame_count": frames.size()}
