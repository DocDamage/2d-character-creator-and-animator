# NumericTransformEditor — Panel controller for exact numeric property editing
class_name NumericTransformEditor
extends Control

signal transform_changed(values: Dictionary)

@onready var pos_x_input: SpinBox = $VBox/Grid/PosXInput
@onready var pos_y_input: SpinBox = $VBox/Grid/PosYInput
@onready var rot_input: SpinBox = $VBox/Grid/RotInput
@onready var scale_x_input: SpinBox = $VBox/Grid/ScaleXInput
@onready var scale_y_input: SpinBox = $VBox/Grid/ScaleYInput
@onready var opacity_input: SpinBox = $VBox/Grid/OpacityInput

var _updating_ui := false


func set_values(p_values: Dictionary) -> void:
	_updating_ui = true
	if pos_x_input != null:
		pos_x_input.value = p_values.get("pos_x", 0.0)
	if pos_y_input != null:
		pos_y_input.value = p_values.get("pos_y", 0.0)
	if rot_input != null:
		rot_input.value = p_values.get("rotation_deg", 0.0)
	if scale_x_input != null:
		scale_x_input.value = p_values.get("scale_x", 1.0)
	if scale_y_input != null:
		scale_y_input.value = p_values.get("scale_y", 1.0)
	if opacity_input != null:
		opacity_input.value = p_values.get("opacity", 1.0)
	_updating_ui = false


func get_values() -> Dictionary:
	return {
		"pos_x": pos_x_input.value if pos_x_input != null else 0.0,
		"pos_y": pos_y_input.value if pos_y_input != null else 0.0,
		"rotation_deg": rot_input.value if rot_input != null else 0.0,
		"scale_x": scale_x_input.value if scale_x_input != null else 1.0,
		"scale_y": scale_y_input.value if scale_y_input != null else 1.0,
		"opacity": opacity_input.value if opacity_input != null else 1.0
	}


func _on_value_changed(_val: float = 0.0) -> void:
	if _updating_ui:
		return
	transform_changed.emit(get_values())
