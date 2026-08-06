# FacingMirrorDialog -- User-facing safe directional cell mirroring.
class_name FacingMirrorDialog
extends AcceptDialog

signal mirror_applied(result: Dictionary)

@onready var source_option: OptionButton = %SourceOption
@onready var destination_option: OptionButton = %DestinationOption
@onready var swap_slots_toggle: CheckBox = %SwapSlotsToggle
@onready var overwrite_toggle: CheckBox = %OverwriteToggle
@onready var mirror_button: Button = %MirrorButton
@onready var result_label: Label = %ResultLabel

var _grid: FacingGridDefinition


func _ready() -> void:
	if not mirror_button.pressed.is_connected(_on_mirror_pressed):
		mirror_button.pressed.connect(_on_mirror_pressed)


func open_for_grid(grid: FacingGridDefinition, preferred_source: String = "") -> void:
	_grid = grid
	_populate_options(preferred_source)
	result_label.text = "Choose a source and destination. Existing destinations require explicit overwrite."
	popup_centered_ratio(0.45)


func set_source_direction(direction_id: String) -> bool:
	return _select_direction(source_option, direction_id)


func set_destination_direction(direction_id: String) -> bool:
	return _select_direction(destination_option, direction_id)


func set_overwrite_enabled(enabled: bool) -> void:
	overwrite_toggle.button_pressed = enabled


func apply_mirror() -> Dictionary:
	if _grid == null:
		return _show_result({"success": false, "message": "Choose a facing grid before mirroring."})
	var source_id := _selected_direction(source_option)
	var destination_id := _selected_direction(destination_option)
	if source_id.is_empty() or destination_id.is_empty() or source_id == destination_id:
		return _show_result({"success": false, "message": "Choose two different valid directions."})
	if _grid.get_cell(source_id).is_empty():
		return _show_result({"success": false, "message": "%s has no cell to mirror." % source_id})
	if not _grid.get_cell(destination_id).is_empty() and not overwrite_toggle.button_pressed:
		return _show_result({"success": false, "message": "%s already has a cell; enable overwrite to replace it." % destination_id})
	if not _grid.mirror_cell(source_id, destination_id, swap_slots_toggle.button_pressed):
		return _show_result({"success": false, "message": "Could not mirror %s to %s." % [source_id, destination_id]})
	var result := {"success": true, "source": source_id, "destination": destination_id}
	result_label.text = "Mirrored %s to %s." % [source_id, destination_id]
	mirror_applied.emit(result.duplicate(true))
	return result


func _populate_options(preferred_source: String) -> void:
	source_option.clear()
	destination_option.clear()
	if _grid == null:
		return
	for direction_value in _grid.get_direction_ids():
		var direction_id := str(direction_value)
		source_option.add_item(direction_id, source_option.item_count)
		destination_option.add_item(direction_id, destination_option.item_count)
	_select_direction(source_option, preferred_source if preferred_source in _grid.get_direction_ids() else str(_grid.get_direction_ids()[0]))
	_select_direction(destination_option, str(_grid.get_direction_ids()[1]) if _grid.get_direction_ids().size() > 1 else "")


func _select_direction(option: OptionButton, direction_id: String) -> bool:
	for index in range(option.item_count):
		if option.get_item_text(index) == direction_id:
			option.select(index)
			return true
	return false


func _selected_direction(option: OptionButton) -> String:
	return option.get_item_text(option.selected) if option != null and option.selected >= 0 else ""


func _show_result(result: Dictionary) -> Dictionary:
	result_label.text = str(result.get("message", "Mirror failed."))
	return result


func _on_mirror_pressed() -> void:
	apply_mirror()
