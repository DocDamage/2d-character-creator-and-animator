# FacingFilenamePlacementDialog -- Preview and atomically apply filename placements.
class_name FacingFilenamePlacementDialog
extends AcceptDialog

signal batch_applied(result: Dictionary)

const FilenamePlacementModelScript = preload("res://facing/facing_filename_placement_model.gd")

@onready var entries_input: TextEdit = %EntriesInput
@onready var preview_button: Button = %PreviewButton
@onready var apply_button: Button = %ApplyButton
@onready var preview_label: Label = %PreviewLabel

var _grid: FacingGridDefinition
var _preview: Dictionary = {}


func _ready() -> void:
	if not preview_button.pressed.is_connected(_on_preview_pressed):
		preview_button.pressed.connect(_on_preview_pressed)
	if not apply_button.pressed.is_connected(_on_apply_pressed):
		apply_button.pressed.connect(_on_apply_pressed)


func open_for_grid(grid: FacingGridDefinition) -> void:
	_grid = grid
	_preview = {}
	apply_button.disabled = true
	preview_label.text = "Enter one asset_id | filename pair per line, then preview."
	popup_centered_ratio(0.65)


func set_entries_text(value: String) -> void:
	entries_input.text = value


func preview_entries() -> Dictionary:
	var parsed := FilenamePlacementModelScript.parse_entries(entries_input.text)
	_preview = FilenamePlacementModelScript.preview(_grid, parsed.get("entries", []) as Array, parsed.get("diagnostics", []) as Array)
	apply_button.disabled = not bool(_preview.get("valid", false))
	preview_label.text = _format_preview(_preview)
	return _preview.duplicate(true)


func apply_preview() -> Dictionary:
	if _preview.is_empty():
		preview_entries()
	var result := FilenamePlacementModelScript.apply(_grid, _preview)
	preview_label.text = _format_apply_result(result)
	if bool(result.get("success", false)):
		apply_button.disabled = true
		batch_applied.emit(result.duplicate(true))
	return result


func _on_preview_pressed() -> void:
	preview_entries()


func _on_apply_pressed() -> void:
	apply_preview()


func _format_preview(plan: Dictionary) -> String:
	var diagnostics := plan.get("diagnostics", []) as Array
	if not diagnostics.is_empty():
		return "Preview blocked:\n- " + "\n- ".join(diagnostics)
	var lines: Array = []
	for match_value in plan.get("matches", []) as Array:
		var match := match_value as Dictionary
		lines.append("%s ← %s" % [match.get("direction_id", ""), match.get("asset_id", "")])
	return "Preview ready (%d assignments):\n%s" % [lines.size(), "\n".join(lines)]


func _format_apply_result(result: Dictionary) -> String:
	if bool(result.get("success", false)):
		return "Applied %d directional assignments." % (result.get("applied", []) as Array).size()
	return "Apply blocked:\n- " + "\n- ".join(result.get("diagnostics", []) as Array)
