# AudioSourceDefinition -- Safe, serializable audio import metadata.
class_name AudioSourceDefinition
extends RefCounted

const SCHEMA_VERSION := "1.0.0"
const SUPPORTED_EXTENSIONS := ["wav", "ogg", "mp3", "flac"]

var audio_id: String = ""
var display_name: String = ""
var source_path: String = ""
var duration_seconds: float = 0.0
var sample_rate: int = 0
var channels: int = 0
var import_settings: Dictionary = {}


func _init(p_id: String = "", p_name: String = "") -> void:
	audio_id = p_id.strip_edges()
	display_name = p_name.strip_edges()


func has_safe_source_path() -> bool:
	return not source_path.is_empty() and not source_path.contains("..") and (source_path.begins_with("res://") or source_path.begins_with("user://"))


func validate(require_source: bool = true) -> Array:
	var errors: Array = []
	if audio_id.is_empty(): errors.append("Audio source requires audio_id.")
	if display_name.is_empty(): errors.append("Audio source '%s' requires display_name." % audio_id)
	if require_source and not has_safe_source_path(): errors.append("Audio source '%s' needs a safe res:// or user:// path." % audio_id)
	if not source_path.is_empty() and source_path.get_extension().to_lower() not in SUPPORTED_EXTENSIONS: errors.append("Audio source '%s' uses an unsupported format." % audio_id)
	if duration_seconds < 0.0: errors.append("Audio source '%s' has negative duration." % audio_id)
	if sample_rate < 0 or channels < 0: errors.append("Audio source '%s' has invalid stream metadata." % audio_id)
	return errors


func to_dict() -> Dictionary:
	return {"schema_version": SCHEMA_VERSION, "audio_id": audio_id, "display_name": display_name, "source_path": source_path, "duration_seconds": duration_seconds, "sample_rate": sample_rate, "channels": channels, "import_settings": import_settings.duplicate(true)}


func from_dict(data: Dictionary) -> AudioSourceDefinition:
	audio_id = str(data.get("audio_id", "")).strip_edges()
	display_name = str(data.get("display_name", "")).strip_edges()
	source_path = str(data.get("source_path", "")).strip_edges()
	duration_seconds = float(data.get("duration_seconds", 0.0))
	sample_rate = int(data.get("sample_rate", 0))
	channels = int(data.get("channels", 0))
	import_settings = (data.get("import_settings", {}) as Dictionary).duplicate(true)
	return self
