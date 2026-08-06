# ShortcutRebindDialog — Interactive modal dialog for rebinding command shortcuts
class_name ShortcutRebindDialog
extends Control

signal rebound(command_id: String, new_shortcut: String)
signal cancelled

@onready var title_label: Label = %CommandTitleLabel
@onready var current_shortcut_label: Label = %CurrentShortcutLabel
@onready var capture_label: Label = %CaptureLabel
@onready var conflict_label: Label = %ConflictLabel
@onready var apply_button: Button = %ApplyButton
@onready var reset_button: Button = %ResetButton
@onready var cancel_button: Button = %CancelButton

var _target_command_id: String = ""
var _captured_shortcut: String = ""
var _is_capturing: bool = false

func _ready() -> void:
	visible = false
	if apply_button != null:
		apply_button.pressed.connect(_on_apply_pressed)
	if reset_button != null:
		reset_button.pressed.connect(_on_reset_pressed)
	if cancel_button != null:
		cancel_button.pressed.connect(_on_cancel_pressed)


func open_for_command(command_id: String) -> void:
	_target_command_id = command_id
	_captured_shortcut = ""
	_is_capturing = true
	visible = true

	if ShortcutRegistry != null:
		var cmd: Dictionary = ShortcutRegistry.get_command(command_id)
		if title_label != null:
			title_label.text = cmd.get("title", command_id) as String
		if current_shortcut_label != null:
			var sc: String = cmd.get("shortcut", "") as String
			current_shortcut_label.text = "Current: " + (sc if not sc.is_empty() else "None")

	if capture_label != null:
		capture_label.text = "Press new shortcut keys..."
	if conflict_label != null:
		conflict_label.text = ""
	if apply_button != null:
		apply_button.disabled = true


func close() -> void:
	_is_capturing = false
	visible = false


func _input(event: InputEvent) -> void:
	if not _is_capturing or not visible or not (event is InputEventKey):
		return
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return

	if key_event.keycode == KEY_ESCAPE:
		_on_cancel_pressed()
		get_viewport().set_input_as_handled()
		return

	if ShortcutRegistry == null:
		return
	var sc_str := ShortcutRegistry.shortcut_to_string(key_event)
	if sc_str.is_empty():
		return

	_captured_shortcut = sc_str
	if capture_label != null:
		capture_label.text = "New Shortcut: " + _captured_shortcut
	if apply_button != null:
		apply_button.disabled = false

	# Conflict detection
	var conflict_cmd: Dictionary = ShortcutRegistry.find_command_by_shortcut(_captured_shortcut)
	var conflict_id: String = conflict_cmd.get("id", "") as String
	if not conflict_id.is_empty() and conflict_id != _target_command_id:
		if conflict_label != null:
			var conflict_title: String = conflict_cmd.get("title", conflict_id) as String
			conflict_label.text = "Warning: Already bound to '" + conflict_title + "'"
	else:
		if conflict_label != null:
			conflict_label.text = ""

	get_viewport().set_input_as_handled()


func _on_apply_pressed() -> void:
	if _target_command_id.is_empty() or _captured_shortcut.is_empty():
		return
	if ShortcutRegistry != null:
		ShortcutRegistry.rebind_shortcut(_target_command_id, _captured_shortcut)
	rebound.emit(_target_command_id, _captured_shortcut)
	close()


func _on_reset_pressed() -> void:
	if _target_command_id.is_empty():
		return
	if ShortcutRegistry != null:
		ShortcutRegistry.reset_shortcut(_target_command_id)
		var cmd := ShortcutRegistry.get_command(_target_command_id)
		var def_sc: String = cmd.get("default_shortcut", "") as String
		rebound.emit(_target_command_id, def_sc)
	close()


func _on_cancel_pressed() -> void:
	cancelled.emit()
	close()
