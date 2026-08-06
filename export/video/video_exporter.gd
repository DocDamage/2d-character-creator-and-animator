# VideoExporter -- Delegates MP4/WebM encoding to a locally available ffmpeg executable.
class_name VideoExporter
extends RefCounted


func is_available() -> bool:
	var output: Array = []
	return OS.execute(_encoder_path(), ["-version"], output, true, false) == 0


func export_sequence(input_pattern: String, output_path: String, fps: float = 24.0, codec: String = "") -> Dictionary:
	if not is_available():
		return {"success": false, "errors": ["ffmpeg is required for video export"]}
	var extension := output_path.get_extension().to_lower()
	if extension not in ["mp4", "webm"]:
		return {"success": false, "errors": ["video extension must be mp4 or webm"]}
	var selected_codec := codec if not codec.is_empty() else ("libx264" if extension == "mp4" else "libvpx-vp9")
	if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output_path).get_base_dir()) != OK:
		return {"success": false, "errors": ["cannot create video directory"]}
	var input_path := ProjectSettings.globalize_path(input_pattern)
	var output_file := ProjectSettings.globalize_path(output_path)
	var arguments := ["-y", "-framerate", str(fps), "-i", input_path, "-c:v", selected_codec]
	arguments.append_array(["-pix_fmt", "yuv420p"])
	arguments.append(output_file)
	var output: Array = []
	var code := OS.execute(_encoder_path(), arguments, output, true, false)
	return {"success": code == 0, "path": output_path, "exit_code": code, "log": "\n".join(output)}


func _encoder_path() -> String:
	var configured := OS.get_environment("FFMPEG_PATH").strip_edges()
	return configured if not configured.is_empty() else "ffmpeg"
