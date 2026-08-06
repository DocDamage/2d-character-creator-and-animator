# UndoHistoryUI — Panel UI listing undo/redo stack history actions
class_name UndoHistoryUI
extends Control

@onready var history_list: ItemList = $VBox/HistoryList
@onready var undo_button: Button = $VBox/Header/UndoButton
@onready var redo_button: Button = $VBox/Header/RedoButton

var _command_history: CommandHistory


func setup(p_history: CommandHistory) -> void:
	_command_history = p_history
	if _command_history != null:
		if not _command_history.history_changed.is_connected(refresh):
			_command_history.history_changed.connect(refresh)
	refresh()


func _ready() -> void:
	if undo_button != null:
		undo_button.pressed.connect(_on_undo_pressed)
	if redo_button != null:
		redo_button.pressed.connect(_on_redo_pressed)


func refresh() -> void:
	if history_list == null:
		return
	history_list.clear()
	
	if _command_history == null:
		if undo_button != null: undo_button.disabled = true
		if redo_button != null: redo_button.disabled = true
		return
	
	var undo_names := _command_history.get_undo_stack_names()
	var redo_names := _command_history.get_redo_stack_names()
	
	for name in undo_names:
		var idx := history_list.add_item("✓ " + name)
		history_list.set_item_custom_fg_color(idx, Color.WHITE)
	
	for name in redo_names:
		var idx := history_list.add_item("↷ " + name)
		history_list.set_item_custom_fg_color(idx, Color.GRAY)
	
	if undo_button != null:
		undo_button.disabled = not _command_history.can_undo()
	if redo_button != null:
		redo_button.disabled = not _command_history.can_redo()


func _on_undo_pressed() -> void:
	if _command_history != null:
		_command_history.undo()


func _on_redo_pressed() -> void:
	if _command_history != null:
		_command_history.redo()
