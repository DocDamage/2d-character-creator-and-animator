# FacingPixelModeControls -- Authoring override for crisp pixel-art facing changes.
class_name FacingPixelModeControls
extends HBoxContainer

@onready var pixel_mode_enabled: CheckButton = %PixelModeEnabled
@onready var status_label: Label = %PixelModeStatusLabel

var _editor: Node
var _updating: bool = false


func _ready() -> void:
	if not pixel_mode_enabled.toggled.is_connected(_on_pixel_mode_toggled):
		pixel_mode_enabled.toggled.connect(_on_pixel_mode_toggled)
	_refresh()


func bind_editor(editor: Node) -> void:
	_editor = editor
	if _editor != null and _editor.has_signal("grid_changed") and not _editor.is_connected("grid_changed", _on_editor_grid_changed):
		_editor.connect("grid_changed", _on_editor_grid_changed)
	_refresh()


func refresh() -> void:
	_refresh()


func set_pixel_mode(enabled: bool) -> bool:
	var grid := _grid()
	if grid == null:
		return false
	grid.pixel_mode = enabled
	_refresh()
	_editor.call("_emit_grid_change", "Pixel mode %s; crossfades are %s." % ["enabled" if enabled else "disabled", "suppressed" if enabled else "available"])
	return true


func _on_pixel_mode_toggled(enabled: bool) -> void:
	if not _updating:
		set_pixel_mode(enabled)


func _on_editor_grid_changed(_grid_data: Dictionary) -> void:
	_refresh()


func _refresh() -> void:
	if not is_node_ready():
		return
	_updating = true
	var grid := _grid()
	pixel_mode_enabled.disabled = grid == null
	pixel_mode_enabled.button_pressed = bool(grid.pixel_mode) if grid != null else false
	status_label.text = "Pixel mode forces hard direction changes." if grid != null and grid.pixel_mode else "Crossfades follow the selected direction blend mode."
	_updating = false


func _grid() -> FacingGridDefinition:
	return _editor.call("get_grid") as FacingGridDefinition if _editor != null else null
