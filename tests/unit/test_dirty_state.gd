# Unit Test — APP-005 Dirty State & Application State Workflows
# Tests dirty flag marking, clean undo stack tracking, autosave signals, document title formatting, and unsaved changes confirmation dialog.
extends Node

const UnsavedDialogScript = preload("res://app/application_state/unsaved_changes_dialog.gd")
const UnsavedDialogScene = preload("res://app/application_state/unsaved_changes_dialog.tscn")

var _pass_count: int = 0
var _fail_count: int = 0
var _test_choice_received: int = -1
var _test_autosave_triggered: bool = false

func run_all() -> Dictionary:
	_pass_count = 0
	_fail_count = 0
	print("\n[TEST 9] Dirty State & Application State Workflows...")

	test_dirty_flag_and_counter()
	test_clean_undo_index_tracking()
	test_document_title_formatting()
	test_autosave_timer_and_signals()
	test_unsaved_changes_dialog_ui()
	test_project_open_close_dirty_state()

	return {"pass": _pass_count, "fail": _fail_count}


func test_dirty_flag_and_counter() -> void:
	AppState.clear_dirty()
	_assert_bool(not AppState.is_dirty(), "AppState initially clean.")
	_assert_int(AppState.get_unsaved_changes(), 0, "Unsaved changes counter initially 0.")

	AppState.mark_dirty()
	_assert_bool(AppState.is_dirty(), "AppState is dirty after mark_dirty().")
	_assert_int(AppState.get_unsaved_changes(), 1, "Unsaved changes counter incremented to 1.")

	AppState.mark_dirty()
	_assert_int(AppState.get_unsaved_changes(), 2, "Unsaved changes counter incremented to 2.")

	AppState.clear_dirty()
	_assert_bool(not AppState.is_dirty(), "AppState clean after clear_dirty().")
	_assert_int(AppState.get_unsaved_changes(), 0, "Unsaved changes counter reset to 0.")


func test_clean_undo_index_tracking() -> void:
	AppState.close_project()
	AppState.open_project("res://sample_project.json")
	AppState.mark_clean()
	_assert_bool(not AppState.is_dirty(), "Project clean after mark_clean().")

	AppState.update_undo_dirty_state(0)
	_assert_bool(not AppState.is_dirty(), "State clean when undo count matches clean undo index.")

	AppState.update_undo_dirty_state(1)
	_assert_bool(AppState.is_dirty(), "State dirty when undo count differs from clean undo index.")

	AppState.update_undo_dirty_state(0)
	_assert_bool(not AppState.is_dirty(), "State clean when returning to clean undo index.")

	AppState.clear_dirty()


func test_document_title_formatting() -> void:
	AppState.close_project()
	var title_unloaded := AppState.get_formatted_title()
	_assert_bool(title_unloaded == "Paper Quest Character Studio", "Unloaded title matches Paper Quest application name.")

	AppState.open_project("c:/projects/my_hero.json")
	var title_clean := AppState.get_formatted_title()
	_assert_bool(title_clean == "my_hero.json - Paper Quest Character Studio", "Clean project title includes file name.")

	AppState.mark_dirty()
	var title_dirty := AppState.get_formatted_title()
	_assert_bool(title_dirty == "my_hero.json - Paper Quest Character Studio *", "Dirty project title appends dirty indicator '*'.")

	AppState.clear_dirty()


func test_autosave_timer_and_signals() -> void:
	AppState.set_autosave_enabled(true)
	AppState.set_autosave_interval(30.0)
	_assert_bool(AppState.is_autosave_enabled(), "Autosave enabled state verified.")
	_assert_bool(is_equal_approx(AppState.get_autosave_interval(), 30.0), "Autosave interval verified.")

	_test_autosave_triggered = false
	var cb := Callable(self, "_on_autosave_test_signal")
	if not AppState.autosave_triggered.is_connected(cb):
		AppState.autosave_triggered.connect(cb)

	AppState.mark_dirty()
	AppState.trigger_autosave()
	_assert_bool(_test_autosave_triggered, "autosave_triggered signal emitted when project is dirty.")

	if AppState.autosave_triggered.is_connected(cb):
		AppState.autosave_triggered.disconnect(cb)
	AppState.clear_dirty()


func test_unsaved_changes_dialog_ui() -> void:
	var dialog: Control = UnsavedDialogScene.instantiate() as Control
	add_child(dialog)

	_assert_bool(dialog != null, "UnsavedChangesDialog scene instantiated.")
	_assert_bool(not dialog.visible, "UnsavedChangesDialog initially hidden.")

	_test_choice_received = -1
	var cb := Callable(self, "_on_dialog_test_choice")

	dialog.call("prompt", "Test prompt message", cb)
	_assert_bool(dialog.visible, "UnsavedChangesDialog visible after prompt().")

	dialog.call("_on_save_pressed")
	_assert_int(_test_choice_received, UnsavedDialogScript.Choice.SAVE, "Prompt callback received Choice.SAVE on Save button press.")
	_assert_bool(not dialog.visible, "UnsavedChangesDialog hidden after choice made.")

	dialog.queue_free()


func test_project_open_close_dirty_state() -> void:
	AppState.close_project()
	_assert_bool(not AppState.is_project_loaded(), "No project loaded initially.")

	AppState.open_project("res://test_game.json")
	_assert_bool(AppState.is_project_loaded(), "Project loaded after open_project().")
	_assert_bool(AppState.get_project_path() == "res://test_game.json", "Project path verified.")
	_assert_bool(not AppState.is_dirty(), "New project opened clean.")

	AppState.mark_dirty()
	_assert_bool(AppState.is_dirty(), "Project marked dirty.")

	AppState.close_project()
	_assert_bool(not AppState.is_project_loaded(), "Project closed successfully.")
	_assert_bool(not AppState.is_dirty(), "Dirty flag cleared on project close.")


func _on_autosave_test_signal() -> void:
	_test_autosave_triggered = true


func _on_dialog_test_choice(choice: int) -> void:
	_test_choice_received = choice


func _assert_bool(cond: bool, msg: String) -> void:
	if cond:
		_pass_count += 1
		print("  PASS: " + msg)
	else:
		_fail_count += 1
		print("  FAIL: " + msg)


func _assert_int(actual: int, expected: int, msg: String) -> void:
	if actual == expected:
		_pass_count += 1
		print("  PASS: " + msg)
	else:
		_fail_count += 1
		print("  FAIL: " + msg + " (Got %d, expected %d)" % [actual, expected])
