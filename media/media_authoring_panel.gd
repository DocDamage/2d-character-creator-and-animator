# MediaAuthoringPanel -- Focusable timeline inspector for sound, lip sync, and reference media.
class_name MediaAuthoringPanel
extends Control

const ModelScript = preload("res://media/media_timeline_model.gd")

@onready var time_input: SpinBox = $Margin/Root/Controls/Time
@onready var status_label: Label = $Margin/Root/Status
@onready var output: RichTextLabel = $Margin/Root/Output

var model = null
var _previous_time: float = 0.0


func _ready() -> void:
	$Margin/Root/Controls/Scrub.pressed.connect(_on_scrub)
	_refresh("Bind media tracks and references to begin.")


func bind_context(audio_track, viseme_track, reference_library = null) -> void:
	model = ModelScript.new()
	model.bind_tracks(audio_track, viseme_track)
	if reference_library != null: model.references = reference_library
	_refresh("Media timeline ready.")


func get_model():
	return model


func _on_scrub() -> void:
	if model == null: return
	var result: Dictionary = model.scrub_to(time_input.value, _previous_time)
	_previous_time = float(result.get("time", 0.0))
	output.text = "Cues: %d\nViseme: %s\nReferences: %d\nMissing: %d" % [result.get("audio_cues", []).size(), str(result.get("viseme", {}).get("viseme_id", "—")), result.get("references", []).size(), result.get("missing_references", []).size()]
	_refresh("Scrubbed to %.3fs" % _previous_time)


func _refresh(message: String) -> void:
	if status_label != null: status_label.text = message
