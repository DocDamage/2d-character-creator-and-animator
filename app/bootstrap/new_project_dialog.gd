# NewProjectDialog — UI dialog for creating a new character project
class_name NewProjectDialog
extends ConfirmationDialog

## === Signals ================================================================

signal project_created(project_path: String, project_title: String, template_id: String)

## === State & Node References ================================================

@onready var _name_input: LineEdit = get_node_or_null("VBox/NameBox/NameEdit")
@onready var _path_input: LineEdit = get_node_or_null("VBox/PathBox/PathEdit")
@onready var _template_select: OptionButton = get_node_or_null("VBox/TemplateBox/TemplateSelect")
@onready var _error_label: Label = get_node_or_null("VBox/ErrorLabel")

const TEMPLATES := [
	{"id": "blank", "name": "Blank Project (Empty Character)"},
	{"id": "sample", "name": "Sample Character (Baseline Rig & Textures)"}
]

## === Lifecycle ==============================================================

func _ready() -> void:
	title = "Create New Project"
	ok_button_text = "Create Project"
	cancel_button_text = "Cancel"
	min_size = Vector2i(450, 260)
	confirmed.connect(_on_confirmed)

	if _template_select != null:
		_template_select.clear()
		for t in TEMPLATES:
			_template_select.add_item(t["name"])
		_template_select.select(0)

	if _name_input != null:
		_name_input.text = "NewCharacter"
		_name_input.text_changed.connect(func(_t): _validate_inputs())

	if _path_input != null:
		_path_input.text = "user://projects/NewCharacter.json"
		_path_input.text_changed.connect(func(_t): _validate_inputs())

	_validate_inputs()


## === Public API =============================================================

func open_dialog() -> void:
	if _name_input != null:
		_name_input.text = "NewCharacter"
	if _path_input != null:
		_path_input.text = "user://projects/NewCharacter.json"
	if _error_label != null:
		_error_label.text = ""
	_validate_inputs()
	popup_centered()


var _fallback_name: String = "NewCharacter"
var _fallback_path: String = "user://projects/NewCharacter.json"

func get_project_name() -> String:
	if _name_input != null:
		return _name_input.text.strip_edges()
	return _fallback_name


func get_project_path() -> String:
	if _path_input != null:
		return _path_input.text.strip_edges()
	return _fallback_path


func get_selected_template() -> String:
	if _template_select != null:
		var idx := _template_select.selected
		if idx >= 0 and idx < TEMPLATES.size():
			return TEMPLATES[idx]["id"]
	return "blank"


## === Internal ===============================================================

func _validate_inputs() -> bool:
	var name_text := get_project_name()
	var path_text := get_project_path()
	var is_valid := true
	var err_msg := ""

	if name_text.is_empty():
		is_valid = false
		err_msg = "Project name cannot be empty."
	elif path_text.is_empty():
		is_valid = false
		err_msg = "Project path cannot be empty."

	if _error_label != null:
		_error_label.text = err_msg

	var ok_btn := get_ok_button()
	if ok_btn != null:
		ok_btn.disabled = not is_valid
	return is_valid


func _on_confirmed() -> void:
	if not _validate_inputs():
		return

	var name_text := get_project_name()
	var path_text := get_project_path()
	var template_id := get_selected_template()

	project_created.emit(path_text, name_text, template_id)
