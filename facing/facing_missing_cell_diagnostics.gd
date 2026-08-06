# FacingMissingCellDiagnostics -- Reachable list and navigation for missing directional cells.
class_name FacingMissingCellDiagnostics
extends VBoxContainer

@onready var summary_label: Label = %MissingCellSummaryLabel
@onready var missing_list: ItemList = %MissingCellList

var _editor: Node
var _missing_direction_ids: Array = []


func _ready() -> void:
	if not missing_list.item_selected.is_connected(_on_missing_item_selected):
		missing_list.item_selected.connect(_on_missing_item_selected)
	_refresh()


func bind_editor(editor: Node) -> void:
	_editor = editor
	if _editor != null and _editor.has_signal("grid_changed") and not _editor.is_connected("grid_changed", _on_editor_grid_changed):
		_editor.connect("grid_changed", _on_editor_grid_changed)
	_refresh()


func refresh() -> void:
	_refresh()


func get_missing_direction_ids() -> Array:
	return _missing_direction_ids.duplicate()


func select_missing_direction(index: int) -> bool:
	if _editor == null or index < 0 or index >= _missing_direction_ids.size():
		return false
	return bool(_editor.call("select_direction", str(_missing_direction_ids[index])))


func _on_missing_item_selected(index: int) -> void:
	select_missing_direction(index)


func _on_editor_grid_changed(_grid_data: Dictionary) -> void:
	_refresh()


func _refresh() -> void:
	if not is_node_ready():
		return
	_missing_direction_ids = _editor.call("get_grid").missing_directions() if _editor != null else []
	missing_list.clear()
	for direction_id in _missing_direction_ids:
		missing_list.add_item(str(direction_id).capitalize().replace("_", " "))
	if _missing_direction_ids.is_empty():
		summary_label.text = "All directional cells are assigned."
	else:
		summary_label.text = "%d missing directional cell%s — select one to assign it." % [_missing_direction_ids.size(), "" if _missing_direction_ids.size() == 1 else "s"]
