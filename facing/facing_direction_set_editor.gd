# FacingDirectionSetEditor -- User-facing editor for 4/8/16/custom directional grids.
class_name FacingDirectionSetEditor
extends Control
signal grid_changed(grid_data: Dictionary)
signal direction_set_changed(direction_set: int, direction_ids: Array)
signal direction_selected(direction_id: String)
signal asset_assigned(direction_id: String, asset_id: String)
signal diagnostics_changed(messages: Array)
const FacingGridDefinitionScript = preload("res://facing/facing_grid_definition.gd")
const EDITABLE_DIRECTION_SETS := [
	FacingGridDefinitionScript.DirectionSet.FOUR_WAY,
	FacingGridDefinitionScript.DirectionSet.EIGHT_WAY,
	FacingGridDefinitionScript.DirectionSet.SIXTEEN_WAY,
	FacingGridDefinitionScript.DirectionSet.CUSTOM,
]
@onready var direction_set_option: OptionButton = %DirectionSetOption
@onready var custom_directions_input: LineEdit = %CustomDirectionsInput
@onready var apply_custom_button: Button = %ApplyCustomButton
@onready var direction_grid: GridContainer = %DirectionGrid
@onready var direction_summary_label: Label = %DirectionSummaryLabel
@onready var selected_direction_label: Label = %SelectedDirectionLabel
@onready var asset_id_input: LineEdit = %AssetIdInput
@onready var assign_asset_button: Button = %AssignAssetButton
@onready var clear_asset_button: Button = %ClearAssetButton
@onready var swap_slots_button: Button = %SwapSlotsButton
@onready var mirror_direction_button: Button = %MirrorDirectionButton
@onready var hard_switch_button: Button = %HardSwitchButton
@onready var filename_batch_button: Button = %FilenameBatchButton
@onready var blend_mode_controls: Node = %BlendModeControls
@onready var mesh_blend_controls: Node = %MeshBlendControls
@onready var direction_scrub_preview: Node = %DirectionScrubPreview
@onready var missing_cell_diagnostics: Node = %MissingCellDiagnostics
@onready var pixel_mode_controls: Node = %PixelModeControls
@onready var filename_placement_dialog: Node = %FilenamePlacementDialog
@onready var facing_mirror_dialog: Node = %FacingMirrorDialog
@onready var feedback_label: Label = %FeedbackLabel
var _grid: FacingGridDefinition
var _selected_direction_id: String = ""
var _diagnostics: Array = []
var _updating_controls: bool = false
func _ready() -> void:
	_setup_direction_set_options()
	if direction_set_option != null and not direction_set_option.item_selected.is_connected(_on_direction_set_selected):
		direction_set_option.item_selected.connect(_on_direction_set_selected)
	if apply_custom_button != null and not apply_custom_button.pressed.is_connected(_on_apply_custom_pressed):
		apply_custom_button.pressed.connect(_on_apply_custom_pressed)
	if assign_asset_button != null and not assign_asset_button.pressed.is_connected(_on_assign_asset_pressed):
		assign_asset_button.pressed.connect(_on_assign_asset_pressed)
	if clear_asset_button != null and not clear_asset_button.pressed.is_connected(_on_clear_asset_pressed):
		clear_asset_button.pressed.connect(_on_clear_asset_pressed)
	if swap_slots_button != null and not swap_slots_button.pressed.is_connected(_on_swap_slots_pressed):
		swap_slots_button.pressed.connect(_on_swap_slots_pressed)
	if mirror_direction_button != null and not mirror_direction_button.pressed.is_connected(_on_mirror_direction_pressed):
		mirror_direction_button.pressed.connect(_on_mirror_direction_pressed)
	if hard_switch_button != null and not hard_switch_button.pressed.is_connected(_on_hard_switch_pressed):
		hard_switch_button.pressed.connect(_on_hard_switch_pressed)
	if blend_mode_controls != null and blend_mode_controls.has_signal("blend_mode_changed") and not blend_mode_controls.is_connected("blend_mode_changed", _on_blend_mode_changed):
		blend_mode_controls.connect("blend_mode_changed", _on_blend_mode_changed)
	if filename_batch_button != null and not filename_batch_button.pressed.is_connected(_on_filename_batch_pressed):
		filename_batch_button.pressed.connect(_on_filename_batch_pressed)
	if filename_placement_dialog != null and filename_placement_dialog.has_signal("batch_applied") and not filename_placement_dialog.is_connected("batch_applied", _on_filename_batch_applied):
		filename_placement_dialog.connect("batch_applied", _on_filename_batch_applied)
	if facing_mirror_dialog != null and facing_mirror_dialog.has_signal("mirror_applied") and not facing_mirror_dialog.is_connected("mirror_applied", _on_mirror_applied):
		facing_mirror_dialog.connect("mirror_applied", _on_mirror_applied)
	if _grid == null:
		bind_grid(FacingGridDefinitionScript.new("facing_grid", "Facing Grid"))
	else:
		_refresh_controls()
	mesh_blend_controls.call("bind_editor", self)
	direction_scrub_preview.call("bind_editor", self)
	missing_cell_diagnostics.call("bind_editor", self)
	pixel_mode_controls.call("bind_editor", self)
func bind_grid(grid: FacingGridDefinition) -> void:
	_grid = grid if grid != null else FacingGridDefinitionScript.new("facing_grid", "Facing Grid")
	_selected_direction_id = ""
	_set_diagnostics([])
	if is_node_ready():
		_refresh_controls()
		blend_mode_controls.call("bind_grid", _grid)
		mesh_blend_controls.call("refresh")
		direction_scrub_preview.call("refresh")
		missing_cell_diagnostics.call("refresh")
		pixel_mode_controls.call("refresh")
func get_grid() -> FacingGridDefinition:
	return _grid
func set_direction_set(direction_set: int, custom_directions: Array = []) -> bool:
	if _grid == null:
		bind_grid(FacingGridDefinitionScript.new("facing_grid", "Facing Grid"))
	if direction_set not in EDITABLE_DIRECTION_SETS:
		_set_diagnostics(["Unsupported direction set: %s" % direction_set])
		return false
	var directions := _normalise_direction_ids(custom_directions)
	if direction_set == FacingGridDefinitionScript.DirectionSet.CUSTOM:
		if directions.size() < 2:
			_set_diagnostics(["Custom direction sets need at least two unique names."])
			return false
	_grid.set_direction_set(direction_set as FacingGridDefinition.DirectionSet, directions)
	_selected_direction_id = ""
	_set_diagnostics([])
	_refresh_controls()
	_emit_grid_change()
	return true
func apply_custom_directions_from_text(value: String) -> bool:
	return set_direction_set(FacingGridDefinitionScript.DirectionSet.CUSTOM, value.split(",", false))
func select_direction(direction_id: String) -> bool:
	if _grid == null or direction_id not in _grid.get_direction_ids():
		_set_diagnostics(["Unknown direction: " + direction_id])
		return false
	_selected_direction_id = direction_id
	_refresh_direction_buttons()
	_refresh_assignment_controls()
	direction_selected.emit(direction_id)
	return true
func get_selected_direction() -> String:
	return _selected_direction_id
func assign_asset_to_selected(asset_id: String) -> bool:
	if _grid == null or _selected_direction_id.is_empty():
		_set_diagnostics(["Select a direction before assigning an asset."])
		return false
	var normalised_asset_id := asset_id.strip_edges()
	if normalised_asset_id.is_empty():
		_set_diagnostics(["Asset ID cannot be empty. Use Clear Asset to remove an assignment."])
		return false
	var cell := _grid.get_cell(_selected_direction_id)
	cell["asset_id"] = normalised_asset_id
	_grid.set_cell(_selected_direction_id, cell)
	_set_diagnostics([])
	_refresh_controls()
	_emit_grid_change("Assigned %s to %s." % [normalised_asset_id, _selected_direction_id])
	asset_assigned.emit(_selected_direction_id, normalised_asset_id)
	return true
func clear_asset_from_selected() -> bool:
	if _grid == null or _selected_direction_id.is_empty():
		_set_diagnostics(["Select a direction before clearing an asset."])
		return false
	var cell := _grid.get_cell(_selected_direction_id)
	if str(cell.get("asset_id", "")).is_empty():
		_set_diagnostics(["%s has no assigned asset to clear." % _selected_direction_id])
		return false
	_grid.remove_cell(_selected_direction_id)
	_set_diagnostics([])
	_refresh_controls()
	_emit_grid_change("Cleared the asset assigned to %s." % _selected_direction_id)
	asset_assigned.emit(_selected_direction_id, "")
	return true
func swap_selected_slots() -> bool:
	if _grid == null or not _grid.swap_cell_slots(_selected_direction_id):
		_set_diagnostics(["Selected direction has no left/right slot mappings to swap."])
		return false
	_set_diagnostics([])
	_refresh_controls()
	_emit_grid_change("Swapped left/right slots in %s." % _selected_direction_id)
	return true

func get_direction_statuses() -> Array:
	var statuses: Array = []
	if _grid == null:
		return statuses
	for direction_id in _grid.get_direction_ids():
		var cell := _grid.get_cell(direction_id)
		statuses.append({
			"direction_id": direction_id,
			"assigned": not str(cell.get("asset_id", "")).is_empty(),
			"selected": direction_id == _selected_direction_id,
		})
	return statuses
func get_diagnostics() -> Array:
	return _diagnostics.duplicate()
func _setup_direction_set_options() -> void:
	if direction_set_option == null or direction_set_option.item_count > 0:
		return
	direction_set_option.add_item("4-way", FacingGridDefinitionScript.DirectionSet.FOUR_WAY)
	direction_set_option.add_item("8-way", FacingGridDefinitionScript.DirectionSet.EIGHT_WAY)
	direction_set_option.add_item("16-way", FacingGridDefinitionScript.DirectionSet.SIXTEEN_WAY)
	direction_set_option.add_item("Custom", FacingGridDefinitionScript.DirectionSet.CUSTOM)

func _refresh_controls() -> void:
	if _grid == null or not is_node_ready():
		return
	_updating_controls = true
	_select_option_for_direction_set(int(_grid.direction_set))
	var is_custom := _grid.direction_set == FacingGridDefinitionScript.DirectionSet.CUSTOM
	custom_directions_input.visible = is_custom
	apply_custom_button.visible = is_custom
	if is_custom:
		custom_directions_input.text = ", ".join(_grid.custom_directions)
	direction_summary_label.text = "%d directions • %d assigned • %d missing" % [
		_grid.get_direction_ids().size(),
		_grid.get_direction_ids().size() - _grid.missing_directions().size(),
		_grid.missing_directions().size(),
	]
	if _selected_direction_id not in _grid.get_direction_ids():
		_selected_direction_id = str(_grid.get_direction_ids()[0]) if not _grid.get_direction_ids().is_empty() else ""
	_refresh_direction_buttons()
	_refresh_assignment_controls()
	_updating_controls = false

func _refresh_direction_buttons() -> void:
	if direction_grid == null or _grid == null:
		return
	for child in direction_grid.get_children():
		direction_grid.remove_child(child)
		child.queue_free()
	for status in get_direction_statuses():
		var direction_id := str(status["direction_id"])
		var button := Button.new()
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.toggle_mode = true
		button.button_pressed = bool(status["selected"])
		button.text = "%s  %s" % [direction_id.capitalize().replace("_", " "), "Assigned" if bool(status["assigned"]) else "Unassigned"]
		button.tooltip_text = "Select %s for the next asset-assignment workflow." % direction_id
		button.pressed.connect(_on_direction_button_pressed.bind(direction_id))
		direction_grid.add_child(button)

func _select_option_for_direction_set(direction_set: int) -> void:
	if direction_set_option == null:
		return
	for index in range(direction_set_option.item_count):
		if direction_set_option.get_item_id(index) == direction_set:
			direction_set_option.select(index)
			return

func _on_direction_set_selected(index: int) -> void:
	if _updating_controls or direction_set_option == null:
		return
	var direction_set := direction_set_option.get_item_id(index)
	var custom_directions: Array = _grid.custom_directions if _grid.direction_set == FacingGridDefinitionScript.DirectionSet.CUSTOM else _grid.get_direction_ids()
	set_direction_set(direction_set, custom_directions)

func _on_apply_custom_pressed() -> void:
	apply_custom_directions_from_text(custom_directions_input.text)

func _on_direction_button_pressed(direction_id: String) -> void:
	select_direction(direction_id)

func _on_assign_asset_pressed() -> void:
	assign_asset_to_selected(asset_id_input.text)

func _on_clear_asset_pressed() -> void:
	clear_asset_from_selected()

func _on_swap_slots_pressed() -> void:
	swap_selected_slots()

func _on_mirror_direction_pressed() -> void:
	facing_mirror_dialog.call("open_for_grid", _grid, _selected_direction_id)

func _on_hard_switch_pressed() -> void:
	_grid.default_blend_mode = FacingGridDefinitionScript.BlendMode.HARD_SWITCH
	blend_mode_controls.call("bind_grid", _grid)
	_set_diagnostics([])
	_emit_grid_change("Hard direction switching enabled.")

func _on_blend_mode_changed(blend_mode: int) -> void:
	_emit_grid_change("Direction blend mode set to %s." % ["hard switch", "nearest direction", "sprite crossfade"][blend_mode])

func _on_mirror_applied(result: Dictionary) -> void:
	_refresh_controls()
	_emit_grid_change("Mirrored %s to %s." % [result.get("source", ""), result.get("destination", "")])

func _on_filename_batch_pressed() -> void:
	filename_placement_dialog.call("open_for_grid", _grid)

func _on_filename_batch_applied(result: Dictionary) -> void:
	_refresh_controls()
	_emit_grid_change("Applied %d filename-based assignments." % (result.get("applied", []) as Array).size())

func _refresh_assignment_controls() -> void:
	if selected_direction_label == null or asset_id_input == null:
		return
	var cell := _grid.get_cell(_selected_direction_id) if _grid != null else {}
	var current_asset_id := str(cell.get("asset_id", ""))
	selected_direction_label.text = "Selected direction: " + (_selected_direction_id if not _selected_direction_id.is_empty() else "None")
	asset_id_input.text = current_asset_id
	asset_id_input.editable = not _selected_direction_id.is_empty()
	assign_asset_button.disabled = _selected_direction_id.is_empty()
	clear_asset_button.disabled = current_asset_id.is_empty()
	swap_slots_button.disabled = _selected_direction_id.is_empty()

func _emit_grid_change(message: String = "Direction set updated. Save the project to persist this grid.") -> void:
	if AppState != null:
		AppState.mark_dirty()
	grid_changed.emit(_grid.to_dict())
	direction_set_changed.emit(int(_grid.direction_set), _grid.get_direction_ids())
	if feedback_label != null:
		feedback_label.text = message + " Save the project to persist this grid."

func _set_diagnostics(messages: Array) -> void:
	_diagnostics = messages.duplicate()
	if is_node_ready() and feedback_label != null:
		feedback_label.text = "\n".join(_diagnostics)
	diagnostics_changed.emit(_diagnostics.duplicate())

func _normalise_direction_ids(values: Array) -> Array:
	var result: Array = []
	for value in values:
		var direction_id := str(value).strip_edges().to_snake_case()
		if not direction_id.is_empty() and direction_id not in result:
			result.append(direction_id)
	return result
