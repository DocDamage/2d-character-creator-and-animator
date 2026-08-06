# FacingDirectionScrubPreview -- Live radial preview for directional evaluation.
class_name FacingDirectionScrubPreview
extends VBoxContainer

const FacingGridEvaluatorScript = preload("res://facing/facing_grid_evaluator.gd")

@onready var scrub_slider: HSlider = %DirectionScrubSlider
@onready var angle_label: Label = %PreviewAngleLabel
@onready var selection_label: Label = %PreviewSelectionLabel
@onready var mesh_label: Label = %PreviewMeshLabel
@onready var preview_canvas: Node = %DirectionPreviewCanvas

var _editor: Node
var _updating: bool = false
var _evaluation: Dictionary = {}


func _ready() -> void:
	if not scrub_slider.value_changed.is_connected(_on_scrub_value_changed):
		scrub_slider.value_changed.connect(_on_scrub_value_changed)
	_refresh()


func bind_editor(editor: Node) -> void:
	_editor = editor
	if _editor != null and _editor.has_signal("grid_changed") and not _editor.is_connected("grid_changed", _on_editor_grid_changed):
		_editor.connect("grid_changed", _on_editor_grid_changed)
	_refresh()


func refresh() -> void:
	_refresh()


func set_angle_degrees(value: float) -> Dictionary:
	scrub_slider.value = fposmod(value, 360.0)
	return _refresh()


func get_evaluation() -> Dictionary:
	return _evaluation.duplicate(true)


func _on_scrub_value_changed(_value: float) -> void:
	if not _updating:
		_refresh()


func _on_editor_grid_changed(_grid_data: Dictionary) -> void:
	_refresh()


func _refresh() -> Dictionary:
	if not is_node_ready():
		return _evaluation
	_updating = true
	var grid := _grid()
	var degrees := scrub_slider.value
	var direction := Vector2(sin(deg_to_rad(degrees)), -cos(deg_to_rad(degrees)))
	_evaluation = FacingGridEvaluatorScript.evaluate(grid, direction) if grid != null else {"valid": false, "reason": "No grid is bound."}
	angle_label.text = "Scrub angle: %.0f°" % degrees
	selection_label.text = _selection_text(_evaluation)
	mesh_label.text = _mesh_text(_evaluation)
	preview_canvas.call("set_preview", direction, _evaluation, grid.get_direction_ids().size() if grid != null else 0)
	_updating = false
	return _evaluation


func _selection_text(result: Dictionary) -> String:
	if not bool(result.get("valid", false)):
		return "Preview unavailable: %s" % str(result.get("reason", "No directions are configured."))
	var primary := str(result.get("primary_direction", "")).capitalize().replace("_", " ")
	if result.get("mode", "") != "crossfade":
		return "Preview: %s (hard selection)" % primary
	var secondary := str(result.get("secondary_direction", "")).capitalize().replace("_", " ")
	return "Preview: %s → %s (crossfade %.0f%%)" % [primary, secondary, float(result.get("weight", 0.0)) * 100.0]


func _mesh_text(result: Dictionary) -> String:
	var mesh_blend := result.get("mesh_blend", {}) as Dictionary
	if bool(mesh_blend.get("compatible", false)):
		return "Mesh preview: %d interpolated vertices." % int(mesh_blend.get("vertex_count", 0))
	return "Mesh preview: %s" % str(mesh_blend.get("reason", "No compatible mesh blend."))


func _grid() -> FacingGridDefinition:
	return _editor.call("get_grid") as FacingGridDefinition if _editor != null else null
