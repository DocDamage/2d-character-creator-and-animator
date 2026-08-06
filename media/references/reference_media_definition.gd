# ReferenceMediaDefinition -- Non-exported timeline reference video, GIF, or image sequence.
class_name ReferenceMediaDefinition
extends RefCounted

const SCHEMA_VERSION := "1.0.0"
const KINDS := ["video", "gif", "image_sequence"]

var reference_id: String = ""
var display_name: String = ""
var kind: String = "video"
var source_path: String = ""
var offset_seconds: float = 0.0
var duration_seconds: float = 0.0
var frame_rate: float = 0.0
var visible_in_preview: bool = true
var exclude_from_export: bool = true
var image_sequence_paths: Array = []


func _init(p_id: String = "", p_name: String = "") -> void:
	reference_id = p_id.strip_edges()
	display_name = p_name.strip_edges()


func is_safe_path(path: String) -> bool:
	return not path.is_empty() and not path.contains("..") and (path.begins_with("res://") or path.begins_with("user://"))


func is_source_missing() -> bool:
	if kind == "image_sequence":
		for path in image_sequence_paths:
			if not FileAccess.file_exists(str(path)): return true
		return image_sequence_paths.is_empty()
	return not FileAccess.file_exists(source_path)


func evaluate_at_timeline_time(timeline_time: float) -> Dictionary:
	var local_time := timeline_time - offset_seconds
	var active := visible_in_preview and local_time >= 0.0 and (duration_seconds <= 0.0 or local_time <= duration_seconds)
	return {"active": active, "local_time": maxf(0.0, local_time), "missing": is_source_missing(), "reference_id": reference_id}


func repair_source(replacement_path: String) -> bool:
	if not is_safe_path(replacement_path) or not FileAccess.file_exists(replacement_path): return false
	source_path = replacement_path
	if kind == "image_sequence": image_sequence_paths = [replacement_path]
	return true


func validate(require_existing_source: bool = false) -> Array:
	var errors: Array = []
	if reference_id.is_empty(): errors.append("Reference media requires reference_id.")
	if display_name.is_empty(): errors.append("Reference media '%s' requires display_name." % reference_id)
	if kind not in KINDS: errors.append("Reference media '%s' uses an unknown kind." % reference_id)
	if kind == "image_sequence":
		for path in image_sequence_paths:
			if not is_safe_path(str(path)): errors.append("Reference image sequence contains an unsafe path.")
	elif not is_safe_path(source_path): errors.append("Reference media '%s' needs a safe source path." % reference_id)
	if duration_seconds < 0.0 or frame_rate < 0.0: errors.append("Reference media '%s' has invalid timing." % reference_id)
	if require_existing_source and is_source_missing(): errors.append("Reference media '%s' source is missing." % reference_id)
	return errors


func to_dict() -> Dictionary:
	return {"schema_version": SCHEMA_VERSION, "reference_id": reference_id, "display_name": display_name, "kind": kind, "source_path": source_path, "offset_seconds": offset_seconds, "duration_seconds": duration_seconds, "frame_rate": frame_rate, "visible_in_preview": visible_in_preview, "exclude_from_export": exclude_from_export, "image_sequence_paths": image_sequence_paths.duplicate()}


func from_dict(data: Dictionary) -> ReferenceMediaDefinition:
	reference_id = str(data.get("reference_id", "")).strip_edges()
	display_name = str(data.get("display_name", "")).strip_edges()
	kind = str(data.get("kind", "video"))
	source_path = str(data.get("source_path", ""))
	offset_seconds = float(data.get("offset_seconds", 0.0))
	duration_seconds = float(data.get("duration_seconds", 0.0))
	frame_rate = float(data.get("frame_rate", 0.0))
	visible_in_preview = bool(data.get("visible_in_preview", true))
	exclude_from_export = bool(data.get("exclude_from_export", true))
	image_sequence_paths = (data.get("image_sequence_paths", []) as Array).duplicate()
	return self
