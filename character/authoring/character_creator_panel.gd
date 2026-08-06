# CharacterCreatorPanel -- Focusable UI bridge for browsing and editing a modular character.
class_name CharacterCreatorPanel
extends Control

const ModelScript = preload("res://character/authoring/character_creator_model.gd")

@onready var search_input: LineEdit = $Margin/Root/Content/Picker/PickerMargin/PickerVBox/Search
@onready var part_list: ItemList = $Margin/Root/Content/Picker/PickerMargin/PickerVBox/PartList
@onready var status_label: Label = $Margin/Root/Status
@onready var seed_input: SpinBox = $Margin/Root/Content/Picker/PickerMargin/PickerVBox/Actions/Seed

var model = null


func _ready() -> void:
	search_input.text_changed.connect(func(_text): refresh_parts())
	part_list.item_activated.connect(_on_part_activated)
	$Margin/Root/Content/Picker/PickerMargin/PickerVBox/Actions/Randomize.pressed.connect(_on_randomize)
	$Margin/Root/Content/Picker/PickerMargin/PickerVBox/Actions/Undo.pressed.connect(_on_undo)
	$Margin/Root/Content/Picker/PickerMargin/PickerVBox/Actions/Redo.pressed.connect(_on_redo)
	_refresh_status("Bind character registries to begin.")


func bind_context(part_registry, slot_registry, body_types: Array, weapons: Array = [], character_id: String = "character", display_name: String = "Character", body_type_id: String = "") -> Dictionary:
	model = ModelScript.new()
	model.configure(part_registry, slot_registry, body_types, weapons)
	model.changed.connect(func(description): refresh_parts(); _refresh_status(description))
	var selected_body := body_type_id
	if selected_body.is_empty() and not body_types.is_empty(): selected_body = body_types[0].body_type_id
	var report: Dictionary = model.create_character(character_id, display_name, selected_body)
	refresh_parts()
	_refresh_status("Character ready." if report.get("success", false) else str(report.get("errors", ["Character setup failed."])[0]))
	return report


func refresh_parts() -> void:
	if model == null or part_list == null: return
	part_list.clear()
	for part in model.browse_parts({"query": search_input.text}):
		part_list.add_item(part.display_name)
		part_list.set_item_metadata(part_list.item_count - 1, part.part_id)


func get_model():
	return model


func _on_part_activated(index: int) -> void:
	if model == null or index < 0: return
	var report: Dictionary = model.equip_part(str(part_list.get_item_metadata(index)))
	_refresh_status("Part equipped." if report.get("success", false) else str(report.get("errors", ["Part could not be equipped."])[0]))
	refresh_parts()


func _on_randomize() -> void:
	if model == null: return
	var report: Dictionary = model.randomize(int(seed_input.value))
	_refresh_status("Randomized character." if report.get("success", false) else str(report.get("errors", ["Randomization failed."])[0]))
	refresh_parts()


func _on_undo() -> void:
	if model != null and model.undo(): _refresh_status("Undid character edit.")


func _on_redo() -> void:
	if model != null and model.redo(): _refresh_status("Redid character edit.")


func _refresh_status(message: String) -> void:
	if status_label == null: return
	var lower := message.to_lower()
	var is_error := "failed" in lower or "could not" in lower or "invalid" in lower or "conflict" in lower
	var is_success := "ready" in lower or "equipped" in lower or "randomized" in lower
	var token := "error" if is_error else ("success" if is_success else "blue")
	status_label.text = ("× " if is_error else ("✓ " if is_success else "i ")) + message
	if ThemeService != null: status_label.add_theme_color_override("font_color", ThemeService.get_color_token(token))
