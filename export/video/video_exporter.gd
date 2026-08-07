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


## Encodes an image sequence with imported cue audio aligned to cue time,
## volume, and pan.  Arguments are passed as an array so artwork paths are not
## interpolated into a shell command.
func export_sequence_with_audio(input_pattern: String, output_path: String, fps: float, cues: Array, codec: String = "") -> Dictionary:
	if cues.is_empty(): return export_sequence(input_pattern, output_path, fps, codec)
	if not is_available(): return {"success": false, "errors": ["ffmpeg is required for video export"]}
	var extension := output_path.get_extension().to_lower()
	if extension != "mp4": return {"success": false, "errors": ["audio mix export currently requires an MP4 output"]}
	if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output_path).get_base_dir()) != OK:
		return {"success": false, "errors": ["cannot create video directory"]}
	var arguments: Array = ["-y", "-framerate", str(fps), "-i", ProjectSettings.globalize_path(input_pattern)]
	var filters: Array = []
	var audio_inputs := 0
	for raw_cue in cues:
		var cue: Dictionary = raw_cue
		var path := str(cue.get("path", ""))
		if path.is_empty() or not FileAccess.file_exists(path):
			return {"success": false, "errors": ["audio cue asset is unavailable: " + path]}
		arguments.append_array(["-i", ProjectSettings.globalize_path(path)])
		var input_index := audio_inputs + 1
		var delay := maxi(0, int(round(float(cue.get("time", 0.0)) * 1000.0)))
		var pan := clampf(float(cue.get("pan", 0.0)), -1.0, 1.0)
		var left := clampf(1.0 - maxf(0.0, pan), 0.0, 1.0)
		var right := clampf(1.0 + minf(0.0, pan), 0.0, 1.0)
		filters.append("[%d:a]aformat=channel_layouts=stereo,adelay=%d:all=1,volume=%fdB,pan=stereo|c0=c0*%.4f|c1=c1*%.4f[a%d]" % [input_index, delay, float(cue.get("volume_db", 0.0)), left, right, audio_inputs])
		audio_inputs += 1
	var labels := ""
	for index in range(audio_inputs): labels += "[a%d]" % index
	filters.append("%samix=inputs=%d:duration=longest:normalize=0[mix]" % [labels, audio_inputs])
	arguments.append_array(["-filter_complex", ";".join(filters), "-map", "0:v", "-map", "[mix]", "-c:v", codec if not codec.is_empty() else "libx264", "-pix_fmt", "yuv420p", "-shortest", ProjectSettings.globalize_path(output_path)])
	var output: Array = []
	var code := OS.execute(_encoder_path(), arguments, output, true, false)
	return {"success": code == 0, "path": output_path, "exit_code": code, "log": "\n".join(output), "audio_cue_count": audio_inputs}


func _encoder_path() -> String:
	var configured := OS.get_environment("FFMPEG_PATH").strip_edges()
	return configured if not configured.is_empty() else "ffmpeg"
