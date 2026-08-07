# RuntimeQaSuite -- Contract-level gameplay QA: collisions, traces, screenshots, and export parity.
class_name RuntimeQaSuite
extends RefCounted

const RuntimePreviewEvaluatorScript = preload("res://runtime_plugin/preview/runtime_preview_evaluator.gd")
const RuntimePackageScript = preload("res://export/project_format/runtime_package.gd")


func run(contract: Dictionary, options: Dictionary = {}) -> Dictionary:
	var evaluator = RuntimePreviewEvaluatorScript.new()
	evaluator.load_contract(contract)
	var clip_id := str(options.get("clip_id", _first_clip_id(contract)))
	var duration := maxf(0.05, float((contract.get("clip_durations", {}) as Dictionary).get(clip_id, 1.0)))
	var fps := clampi(int(options.get("fps", 24)), 1, 240)
	var frames := _playback(evaluator, clip_id, duration, fps)
	var collisions := _collisions(frames)
	var expected_points: Array = options.get("expected_action_points", []) as Array
	var action_test := _action_point_test(frames, expected_points)
	var output := str(options.get("output_directory", ""))
	var screenshots := capture_regression_screenshots(frames, output.path_join("runtime_regressions") if not output.is_empty() else "")
	var report := {"success": bool(action_test.get("success", false)), "clip_id": clip_id, "frames": frames.size(), "collision_playback": collisions, "action_point_test": action_test, "event_trace": evaluator.get_trace(), "screenshots": screenshots, "contract_hash": str(contract.get("content_hash", ""))}
	if not output.is_empty(): _write_json(output.path_join("runtime_qa_report.json"), report)
	return report


func compare_exported_package(source_contract: Dictionary, package_path: String, options: Dictionary = {}) -> Dictionary:
	var loaded := RuntimePackageScript.load(package_path)
	if not bool(loaded.get("success", false)): return {"matches": false, "errors": loaded.get("errors", [])}
	var exported: Dictionary = (loaded.get("package", {}).get("content", {}) as Dictionary).duplicate(true)
	var source_report := run(source_contract, options)
	var exported_report := run(exported, options)
	var differences: Array = []
	if str(source_contract.get("content_hash", "")) != str(exported.get("content_hash", "")): differences.append("runtime contract hash differs")
	if source_report.get("collision_playback", []) != exported_report.get("collision_playback", []): differences.append("collision playback differs")
	if _event_names(source_report.get("event_trace", []) as Array) != _event_names(exported_report.get("event_trace", []) as Array): differences.append("event trace differs")
	return {"matches": differences.is_empty(), "differences": differences, "source": source_report, "exported": exported_report}


func capture_regression_screenshots(frames: Array, output_directory: String) -> Array:
	var paths: Array = []
	if output_directory.strip_edges().is_empty(): return paths
	var absolute := _absolute(output_directory)
	if DirAccess.make_dir_recursive_absolute(absolute) != OK: return paths
	var selected: Array = []
	if not frames.is_empty(): selected.append(frames[0])
	if frames.size() > 2: selected.append(frames[frames.size() / 2])
	if frames.size() > 1: selected.append(frames[frames.size() - 1])
	for index in range(selected.size()):
		var image := _debug_image(selected[index] as Dictionary)
		var path := output_directory.path_join("runtime_%02d.png" % index)
		if image.save_png(_absolute(path)) == OK: paths.append(path)
	return paths


func _playback(evaluator, clip_id: String, duration: float, fps: int) -> Array:
	var frames: Array = []
	var frame_count := maxi(1, int(ceil(duration * fps)))
	frames.append(evaluator.sample({"clip_id": clip_id, "time": 0.0, "force_clip": true}))
	for index in range(1, frame_count + 1): frames.append(evaluator.tick(duration / float(frame_count), {"clip_id": clip_id, "force_clip": true}))
	return frames


func _action_point_test(frames: Array, expected: Array) -> Dictionary:
	var found: Dictionary = {}
	for raw_frame in frames:
		for raw_point in (raw_frame as Dictionary).get("action_points", []) as Array:
			var point: Dictionary = (raw_point as Dictionary).get("value", {}) as Dictionary
			var id := str(point.get("point_id", point.get("display_name", "")))
			if not id.is_empty(): found[id] = true
	var missing: Array = []
	for id in expected:
		if not found.has(str(id)): missing.append(str(id))
	return {"success": missing.is_empty(), "found": found.keys(), "missing": missing}


func _collisions(frames: Array) -> Array:
	var results: Array = []
	for raw_frame in frames:
		var frame: Dictionary = raw_frame as Dictionary
		for hit in frame.get("hitboxes", []) as Array:
			for hurt in frame.get("hurtboxes", []) as Array:
				if _bounds(hit as Dictionary).intersects(_bounds(hurt as Dictionary)):
					results.append({"time": float(frame.get("clip_time", 0.0)), "hitbox": str((hit as Dictionary).get("shape_id", (hit as Dictionary).get("track_id", ""))), "hurtbox": str((hurt as Dictionary).get("shape_id", (hurt as Dictionary).get("track_id", "")))})
	return results


func _bounds(shape: Dictionary) -> Rect2:
	var position := _vector(shape.get("local_position", [0.0, 0.0]))
	var size := _vector(shape.get("size", [16.0, 16.0]))
	if int(shape.get("shape_type", 0)) == 1:
		var radius := maxf(0.0, float(shape.get("radius", 0.0)))
		size = Vector2.ONE * radius * 2.0
	return Rect2(position - size * 0.5, size)


func _debug_image(frame: Dictionary) -> Image:
	var image := Image.create(320, 180, false, Image.FORMAT_RGBA8)
	image.fill(Color("111827"))
	for hit in frame.get("hitboxes", []) as Array: _draw_rect(image, _bounds(hit as Dictionary), Color("ef4444"))
	for hurt in frame.get("hurtboxes", []) as Array: _draw_rect(image, _bounds(hurt as Dictionary), Color("38bdf8"))
	for raw_point in frame.get("action_points", []) as Array:
		var point: Dictionary = (raw_point as Dictionary).get("value", {}) as Dictionary
		var position := _vector(point.get("local_position", [0.0, 0.0])) + Vector2(160, 90)
		for offset in [Vector2(-2, 0), Vector2(-1, 0), Vector2.ZERO, Vector2(1, 0), Vector2(2, 0), Vector2(0, -2), Vector2(0, -1), Vector2(0, 1), Vector2(0, 2)]: image.set_pixelv(Vector2i(position + offset), Color("facc15"))
	return image


func _draw_rect(image: Image, bounds: Rect2, color: Color) -> void:
	var rect := Rect2i(Vector2i(bounds.position + Vector2(160, 90)), Vector2i(bounds.size))
	for x in range(rect.position.x, rect.end.x):
		if x >= 0 and x < image.get_width():
			if rect.position.y >= 0 and rect.position.y < image.get_height(): image.set_pixel(x, rect.position.y, color)
			if rect.end.y - 1 >= 0 and rect.end.y - 1 < image.get_height(): image.set_pixel(x, rect.end.y - 1, color)
	for y in range(rect.position.y, rect.end.y):
		if y >= 0 and y < image.get_height():
			if rect.position.x >= 0 and rect.position.x < image.get_width(): image.set_pixel(rect.position.x, y, color)
			if rect.end.x - 1 >= 0 and rect.end.x - 1 < image.get_width(): image.set_pixel(rect.end.x - 1, y, color)


func _event_names(trace: Array) -> Array:
	var result: Array = []
	for entry in trace:
		for event in (entry as Dictionary).get("events", []) as Array: result.append(str((event as Dictionary).get("event_name", (event as Dictionary).get("event_id", ""))))
	return result


func _first_clip_id(contract: Dictionary) -> String:
	var ids: Array = (contract.get("clips", {}) as Dictionary).keys()
	ids.sort()
	return str(ids[0]) if not ids.is_empty() else ""


func _write_json(path: String, data: Dictionary) -> void:
	var absolute := _absolute(path)
	if DirAccess.make_dir_recursive_absolute(absolute.get_base_dir()) != OK: return
	var file := FileAccess.open(absolute, FileAccess.WRITE)
	if file != null: file.store_string(JSON.stringify(data, "\t", true, false)); file.close()


func _absolute(path: String) -> String:
	return ProjectSettings.globalize_path(path) if path.begins_with("res://") or path.begins_with("user://") else path


func _vector(value: Variant) -> Vector2:
	if value is Vector2: return value as Vector2
	if value is Array and (value as Array).size() >= 2: return Vector2(float((value as Array)[0]), float((value as Array)[1]))
	return Vector2.ZERO
