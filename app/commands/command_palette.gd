# CommandPalette — Interactive modal search overlay for commands and shortcuts
class_name CommandPalette
extends Control

signal opened
signal closed
signal command_selected(command_id: String)

@onready var search_input: LineEdit = %SearchInput
@onready var results_tree: Tree = %ResultsTree
@onready var hint_label: Label = %HintLabel

var _filtered_commands: Array[Dictionary] = []
var _is_open: bool = false

func _ready() -> void:
	visible = false
	if search_input != null:
		search_input.text_changed.connect(_on_search_text_changed)
		search_input.gui_input.connect(_on_search_gui_input)
	if results_tree != null:
		results_tree.columns = 3
		results_tree.set_column_title(0, "Command")
		results_tree.set_column_title(1, "Category")
		results_tree.set_column_title(2, "Shortcut")
		results_tree.set_column_expand(0, true)
		results_tree.set_column_expand(1, false)
		results_tree.set_column_expand(2, false)
		results_tree.set_column_custom_minimum_width(1, 120)
		results_tree.set_column_custom_minimum_width(2, 100)
		results_tree.item_activated.connect(_on_item_activated)


func open() -> void:
	_is_open = true
	visible = true
	if search_input != null:
		search_input.text = ""
		search_input.grab_focus()
	refresh_results()
	opened.emit()
	if DiagnosticsService != null:
		DiagnosticsService.info("Command Palette opened", "CommandPalette")


func close() -> void:
	_is_open = false
	visible = false
	closed.emit()


func toggle() -> void:
	if _is_open:
		close()
	else:
		open()


func is_open() -> bool:
	return _is_open


func refresh_results(query: String = "") -> void:
	if ShortcutRegistry == null:
		return
	_filtered_commands = ShortcutRegistry.search_commands(query)
	_populate_tree()


func get_filtered_count() -> int:
	return _filtered_commands.size()


func get_selected_command_id() -> String:
	if results_tree == null:
		return ""
	var selected := results_tree.get_selected()
	if selected == null:
		return ""
	var idx := selected.get_meta("cmd_index", -1) as int
	if idx >= 0 and idx < _filtered_commands.size():
		return _filtered_commands[idx].get("id", "") as String
	return ""


func execute_selected() -> bool:
	var cid := get_selected_command_id()
	if cid.is_empty():
		return false
	command_selected.emit(cid)
	close()
	if ShortcutRegistry != null:
		return ShortcutRegistry.execute_command(cid)
	return false


func _populate_tree() -> void:
	if results_tree == null:
		return
	results_tree.clear()
	var root := results_tree.create_item()

	for i in range(_filtered_commands.size()):
		var cmd := _filtered_commands[i]
		var item := results_tree.create_item(root)
		item.set_text(0, cmd.get("title", "") as String)
		item.set_text(1, cmd.get("category", "General") as String)
		var sc: String = cmd.get("shortcut", "") as String
		item.set_text(2, sc if not sc.is_empty() else "—")
		item.set_meta("cmd_index", i)

	if root.get_child_count() > 0:
		var first_child := root.get_child(0)
		first_child.select(0)


func _on_search_text_changed(new_text: String) -> void:
	refresh_results(new_text)


func _on_search_gui_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var key_event := event as InputEventKey
	if not key_event.pressed:
		return

	if key_event.keycode == KEY_DOWN or key_event.keycode == KEY_UP:
		_navigate_tree(key_event.keycode == KEY_DOWN)
		accept_event()
	elif key_event.keycode == KEY_ENTER or key_event.keycode == KEY_KP_ENTER:
		execute_selected()
		accept_event()
	elif key_event.keycode == KEY_ESCAPE:
		close()
		accept_event()


func _navigate_tree(move_down: bool) -> void:
	if results_tree == null:
		return
	var selected := results_tree.get_selected()
	if selected == null:
		var root := results_tree.get_root()
		if root != null and root.get_child_count() > 0:
			root.get_child(0).select(0)
		return

	var next_item: TreeItem = selected.get_next() if move_down else selected.get_prev()
	if next_item != null:
		next_item.select(0)
		results_tree.scroll_to_item(next_item)


func _on_item_activated() -> void:
	execute_selected()
