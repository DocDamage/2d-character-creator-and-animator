# UnsavedChangesDialog — Modal confirmation dialog for unsaved project modifications
# Prompts user with options to Save, Discard (Don't Save), or Cancel when closing or opening projects.
class_name UnsavedChangesDialog
extends Control

## === Enums & Signals =========================================================

enum Choice {
	SAVE,
	DISCARD,
	CANCEL,
}

signal choice_made(choice: int)

## === Node References ========================================================

@onready var title_label: Label = %TitleLabel
@onready var message_label: Label = %MessageLabel
@onready var save_button: Button = %SaveButton
@onready var discard_button: Button = %DiscardButton
@onready var cancel_button: Button = %CancelButton

## === State ==================================================================

var _last_choice: int = Choice.CANCEL
var _pending_callback: Callable = Callable()

## === Lifecycle ==============================================================

func _ready() -> void:
	visible = false
	_connect_signals()


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var key_event := event as InputEventKey
		if key_event.keycode == KEY_ESCAPE:
			_make_choice(Choice.CANCEL)
			get_viewport().set_input_as_handled()


## === Public API =============================================================

func prompt(message: String = "", callback: Callable = Callable()) -> void:
	_pending_callback = callback
	if message_label != null and not message.is_empty():
		message_label.text = message
	open()


func open() -> void:
	_last_choice = Choice.CANCEL
	visible = true
	if save_button != null:
		save_button.grab_focus()


func close() -> void:
	visible = false


func get_last_choice() -> int:
	return _last_choice


## === Internal ===============================================================

func _connect_signals() -> void:
	if save_button != null and not save_button.pressed.is_connected(_on_save_pressed):
		save_button.pressed.connect(_on_save_pressed)
	if discard_button != null and not discard_button.pressed.is_connected(_on_discard_pressed):
		discard_button.pressed.connect(_on_discard_pressed)
	if cancel_button != null and not cancel_button.pressed.is_connected(_on_cancel_pressed):
		cancel_button.pressed.connect(_on_cancel_pressed)


func _on_save_pressed() -> void:
	_make_choice(Choice.SAVE)


func _on_discard_pressed() -> void:
	_make_choice(Choice.DISCARD)


func _on_cancel_pressed() -> void:
	_make_choice(Choice.CANCEL)


func _make_choice(choice: int) -> void:
	_last_choice = choice
	close()
	choice_made.emit(choice)
	if _pending_callback.is_valid():
		var cb := _pending_callback
		_pending_callback = Callable()
		cb.call(choice)
