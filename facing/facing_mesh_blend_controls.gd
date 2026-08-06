# FacingMeshBlendControls -- User controls and feedback for directional mesh blending.
class_name FacingMeshBlendControls
extends VBoxContainer

const FacingMeshBlendModelScript = preload("res://facing/facing_mesh_blend_model.gd")

@onready var mesh_blend_enabled: CheckButton = %MeshBlendEnabled
@onready var status_label: Label = %MeshBlendStatusLabel
@onready var mesh_id_input: LineEdit = %MeshIdInput
@onready var topology_id_input: LineEdit = %TopologyIdInput
@onready var vertices_input: LineEdit = %MeshVerticesInput
@onready var apply_mesh_data_button: Button = %ApplyMeshDataButton

var _editor: Node
var _updating: bool = false


func _ready() -> void:
	if not mesh_blend_enabled.toggled.is_connected(_on_mesh_blend_toggled):
		mesh_blend_enabled.toggled.connect(_on_mesh_blend_toggled)
	if not apply_mesh_data_button.pressed.is_connected(_on_apply_mesh_data_pressed):
		apply_mesh_data_button.pressed.connect(_on_apply_mesh_data_pressed)
	_refresh()


func bind_editor(editor: Node) -> void:
	_editor = editor
	if _editor != null and _editor.has_signal("direction_selected") and not _editor.is_connected("direction_selected", _on_editor_changed):
		_editor.connect("direction_selected", _on_editor_changed)
	if _editor != null and _editor.has_signal("grid_changed") and not _editor.is_connected("grid_changed", _on_editor_grid_changed):
		_editor.connect("grid_changed", _on_editor_grid_changed)
	_refresh()


func refresh() -> void:
	_refresh()


func set_mesh_blend_enabled(enabled: bool) -> bool:
	var grid := _grid()
	var direction_id := _selected_direction_id()
	if grid == null or direction_id.is_empty():
		return false
	var cell: Dictionary = grid.get_cell(direction_id)
	var deformation := (cell.get("deformation", {}) as Dictionary).duplicate(true)
	deformation["mesh_blend_enabled"] = enabled
	cell["deformation"] = deformation
	grid.set_cell(direction_id, cell)
	_refresh()
	_editor.call("_emit_grid_change", "Mesh blending %s for %s." % ["enabled" if enabled else "disabled", direction_id])
	return true


func set_mesh_deformation(mesh_id: String, topology_id: String, vertex_text: String) -> bool:
	var grid := _grid()
	var direction_id := _selected_direction_id()
	if grid == null or direction_id.is_empty() or mesh_id.strip_edges().is_empty():
		return false
	var parsed_vertices := _parse_vertices(vertex_text)
	if not bool(parsed_vertices["valid"]):
		status_label.text = str(parsed_vertices["reason"])
		return false
	var cell: Dictionary = grid.get_cell(direction_id)
	var deformation := (cell.get("deformation", {}) as Dictionary).duplicate(true)
	deformation["topology_id"] = topology_id.strip_edges() if not topology_id.strip_edges().is_empty() else mesh_id.strip_edges()
	deformation["mesh_vertices"] = parsed_vertices["vertices"]
	cell["mesh_id"] = mesh_id.strip_edges()
	cell["deformation"] = deformation
	grid.set_cell(direction_id, cell)
	_refresh()
	_editor.call("_emit_grid_change", "Mesh deformation stored for %s." % direction_id)
	return true


func _on_mesh_blend_toggled(enabled: bool) -> void:
	if not _updating:
		set_mesh_blend_enabled(enabled)


func _on_apply_mesh_data_pressed() -> void:
	set_mesh_deformation(mesh_id_input.text, topology_id_input.text, vertices_input.text)


func _on_editor_changed(_direction_id: String) -> void:
	_refresh()


func _on_editor_grid_changed(_grid_data: Dictionary) -> void:
	_refresh()


func _refresh() -> void:
	if not is_node_ready():
		return
	_updating = true
	var grid := _grid()
	var direction_id := _selected_direction_id()
	var cell: Dictionary = grid.get_cell(direction_id) if grid != null and not direction_id.is_empty() else {}
	mesh_blend_enabled.disabled = cell.is_empty()
	mesh_blend_enabled.button_pressed = bool((cell.get("deformation", {}) as Dictionary).get("mesh_blend_enabled", true))
	var editable := grid != null and not direction_id.is_empty()
	mesh_id_input.editable = editable
	topology_id_input.editable = editable
	vertices_input.editable = editable
	apply_mesh_data_button.disabled = not editable
	if editable:
		var deformation := cell.get("deformation", {}) as Dictionary
		mesh_id_input.text = str(cell.get("mesh_id", ""))
		topology_id_input.text = str(deformation.get("topology_id", ""))
		vertices_input.text = _vertices_to_text(deformation.get("mesh_vertices", deformation.get("vertices", [])) as Array)
	status_label.text = _status_for(grid, direction_id, cell)
	_updating = false


func _status_for(grid, direction_id: String, cell: Dictionary) -> String:
	if grid == null or direction_id.is_empty():
		return "Select a direction cell to configure mesh blending."
	if cell.is_empty():
		return "Enter mesh data for this direction, then compare it with the next cell."
	var direction_ids: Array = grid.get_direction_ids()
	var index := direction_ids.find(direction_id)
	var neighbor_id := str(direction_ids[(index + 1) % direction_ids.size()])
	var result := FacingMeshBlendModelScript.validate_cells(cell, grid.get_cell(neighbor_id))
	if bool(result["compatible"]):
		return "Mesh blend with %s is ready (%d vertices)." % [neighbor_id, int(result["vertex_count"])]
	return "Mesh blend with %s unavailable: %s" % [neighbor_id, str(result["reason"])]


func _grid() -> FacingGridDefinition:
	return _editor.call("get_grid") as FacingGridDefinition if _editor != null else null


func _selected_direction_id() -> String:
	return str(_editor.call("get_selected_direction")) if _editor != null else ""


func _parse_vertices(value: String) -> Dictionary:
	var vertices: Array = []
	for pair_text in value.split(";", false):
		var coordinates := pair_text.strip_edges().split(",", false)
		if coordinates.size() != 2 or not coordinates[0].strip_edges().is_valid_float() or not coordinates[1].strip_edges().is_valid_float():
			return {"valid": false, "reason": "Vertices must use x,y; x,y format.", "vertices": []}
		vertices.append([float(coordinates[0]), float(coordinates[1])])
	if vertices.is_empty():
		return {"valid": false, "reason": "Enter at least one deformation vertex.", "vertices": []}
	return {"valid": true, "reason": "", "vertices": vertices}


func _vertices_to_text(values: Array) -> String:
	var pairs: Array = []
	for value in values:
		if value is Vector2:
			pairs.append("%s,%s" % [value.x, value.y])
		elif value is Array and value.size() >= 2:
			pairs.append("%s,%s" % [value[0], value[1]])
	return "; ".join(pairs)
