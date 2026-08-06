# FacingBlendModeControls -- Reusable authoring controls for directional blend modes.
class_name FacingBlendModeControls
extends HBoxContainer

signal blend_mode_changed(blend_mode: int)

const FacingGridDefinitionScript = preload("res://facing/facing_grid_definition.gd")

@onready var blend_mode_option: OptionButton = %BlendModeOption
@onready var status_label: Label = %BlendModeStatusLabel

var _grid: FacingGridDefinition
var _updating: bool = false


func _ready() -> void:
	if blend_mode_option.item_count == 0:
		blend_mode_option.add_item("Hard switch", FacingGridDefinitionScript.BlendMode.HARD_SWITCH)
		blend_mode_option.add_item("Nearest direction", FacingGridDefinitionScript.BlendMode.NEAREST)
		blend_mode_option.add_item("Sprite crossfade", FacingGridDefinitionScript.BlendMode.CROSSFADE)
	if not blend_mode_option.item_selected.is_connected(_on_blend_mode_selected):
		blend_mode_option.item_selected.connect(_on_blend_mode_selected)
	_refresh()


func bind_grid(grid: FacingGridDefinition) -> void:
	_grid = grid
	_refresh()


func set_blend_mode(blend_mode: int) -> bool:
	if _grid == null or blend_mode not in [FacingGridDefinitionScript.BlendMode.HARD_SWITCH, FacingGridDefinitionScript.BlendMode.NEAREST, FacingGridDefinitionScript.BlendMode.CROSSFADE]:
		return false
	_grid.default_blend_mode = blend_mode as FacingGridDefinition.BlendMode
	_refresh()
	blend_mode_changed.emit(blend_mode)
	return true


func _on_blend_mode_selected(index: int) -> void:
	if not _updating:
		set_blend_mode(blend_mode_option.get_item_id(index))


func _refresh() -> void:
	if not is_node_ready():
		return
	_updating = true
	var mode := int(_grid.default_blend_mode) if _grid != null else FacingGridDefinitionScript.BlendMode.HARD_SWITCH
	for index in range(blend_mode_option.item_count):
		if blend_mode_option.get_item_id(index) == mode:
			blend_mode_option.select(index)
	status_label.text = "Crossfade blends adjacent sprite cells." if mode == FacingGridDefinitionScript.BlendMode.CROSSFADE else "Select a direction-blending mode."
	_updating = false
