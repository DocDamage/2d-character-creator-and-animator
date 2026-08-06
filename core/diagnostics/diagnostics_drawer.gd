# DiagnosticsDrawer — UI Drawer for system log entries, filtering, and source navigation
class_name DiagnosticsDrawer
extends Control

## === Signals ================================================================

signal entry_selected(entry: Dictionary)
signal source_navigated(source_path: String, line_number: int)
signal filter_changed(active_levels: Array)

## === UI Node References ====================================================

@onready var search_input: LineEdit = %SearchInput
@onready var tree: Tree = %LogTree
@onready var btn_all: Button = %BtnAll
@onready var btn_info: Button = %BtnInfo
@onready var btn_warning: Button = %BtnWarning
@onready var btn_error: Button = %BtnError
@onready var btn_debug: Button = %BtnDebug
@onready var btn_clear: Button = %BtnClear
@onready var btn_export: Button = %BtnExport
@onready var btn_autoscroll: CheckButton = %BtnAutoScroll
@onready var lbl_counts: Label = %LblCounts
@onready var lbl_detail: Label = %LblDetail

## === State ==================================================================

var _search_query: String = ""
var _selected_entry: Dictionary = {}
var _auto_scroll: bool = true
var _active_level_filter: Array = [2, 3, 4, 5] # Default: INFO, WARNING, ERROR, FATAL

## === Lifecycle ==============================================================

func _ready() -> void:
	_setup_tree()
	_setup_signals()
	_connect_diagnostics_service()
	refresh()


## === Public API =============================================================

func refresh() -> void:
	if DiagnosticsService == null:
		return
	_update_counts_label()
	_populate_tree()


func set_search_query(query: String) -> void:
	_search_query = query.strip_edges().to_lower()
	_populate_tree()


func set_level_filter(levels: Array) -> void:
	_active_level_filter = levels.duplicate()
	if DiagnosticsService != null:
		DiagnosticsService.set_filter(levels)
	filter_changed.emit(_active_level_filter)
	_update_filter_button_states()
	_populate_tree()


func clear_logs() -> void:
	if DiagnosticsService != null:
		DiagnosticsService.clear()
	_selected_entry = {}
	if lbl_detail != null:
		lbl_detail.text = "Select a log entry to view details."
	refresh()


func export_logs() -> String:
	if DiagnosticsService != null:
		var text := DiagnosticsService.export_entries()
		DisplayServer.clipboard_set(text)
		return text
	return ""


func get_selected_entry() -> Dictionary:
	return _selected_entry


## === Internal Setup =========================================================

func _setup_tree() -> void:
	if tree == null:
		return
	tree.clear()
	tree.columns = 4
	tree.set_column_title(0, "Level")
	tree.set_column_title(1, "Time")
	tree.set_column_title(2, "Source")
	tree.set_column_title(3, "Message")
	tree.set_column_titles_visible(true)
	tree.set_column_expand(0, false)
	tree.set_column_custom_minimum_width(0, 80)
	tree.set_column_expand(1, false)
	tree.set_column_custom_minimum_width(1, 90)
	tree.set_column_expand(2, false)
	tree.set_column_custom_minimum_width(2, 140)
	tree.set_column_expand(3, true)
	tree.select_mode = Tree.SELECT_ROW


func _setup_signals() -> void:
	if search_input != null and not search_input.text_changed.is_connected(_on_search_changed):
		search_input.text_changed.connect(_on_search_changed)
	if tree != null and not tree.item_selected.is_connected(_on_tree_item_selected):
		tree.item_selected.connect(_on_tree_item_selected)
	if tree != null and not tree.item_activated.is_connected(_on_tree_item_activated):
		tree.item_activated.connect(_on_tree_item_activated)

	if btn_all != null:
		btn_all.pressed.connect(func(): set_level_filter([0, 1, 2, 3, 4, 5]))
	if btn_info != null:
		btn_info.pressed.connect(func(): set_level_filter([2]))
	if btn_warning != null:
		btn_warning.pressed.connect(func(): set_level_filter([3]))
	if btn_error != null:
		btn_error.pressed.connect(func(): set_level_filter([4, 5]))
	if btn_debug != null:
		btn_debug.pressed.connect(func(): set_level_filter([0, 1]))

	if btn_clear != null:
		btn_clear.pressed.connect(clear_logs)
	if btn_export != null:
		btn_export.pressed.connect(func(): export_logs())
	if btn_autoscroll != null:
		btn_autoscroll.toggled.connect(func(toggled: bool): _auto_scroll = toggled)


func _connect_diagnostics_service() -> void:
	if DiagnosticsService == null:
		return
	if not DiagnosticsService.entry_added.is_connected(_on_entry_added):
		DiagnosticsService.entry_added.connect(_on_entry_added)
	if not DiagnosticsService.count_changed.is_connected(_on_count_changed):
		DiagnosticsService.count_changed.connect(_on_count_changed)


## === Tree Rendering & Population ============================================

func _populate_tree() -> void:
	if tree == null or DiagnosticsService == null:
		return
	tree.clear()
	var root := tree.create_item()

	var entries: Array[Dictionary] = DiagnosticsService.get_entries(_active_level_filter)
	var last_item: TreeItem = null

	for entry in entries:
		if not _matches_search(entry):
			continue
		last_item = _create_tree_row(root, entry)

	if _auto_scroll and last_item != null:
		tree.scroll_to_item(last_item)


func _create_tree_row(parent: TreeItem, entry: Dictionary) -> TreeItem:
	var item := tree.create_item(parent)
	var lvl: int = entry.get("level", 2) as int
	var lvl_name: String = (entry.get("level_name", "info") as String).to_upper()
	var ts: float = entry.get("timestamp", 0.0) as float
	var time_str := Time.get_time_string_from_unix_time(int(ts))
	var source: String = entry.get("source", "") as String
	var msg: String = entry.get("message", "") as String

	item.set_text(0, lvl_name)
	item.set_text(1, time_str)
	item.set_text(2, source)
	item.set_text(3, msg)

	var color := _get_level_color(lvl)
	item.set_custom_color(0, color)
	item.set_metadata(0, entry)
	return item


func _matches_search(entry: Dictionary) -> bool:
	if _search_query.is_empty():
		return true
	var msg: String = (entry.get("message", "") as String).to_lower()
	var src: String = (entry.get("source", "") as String).to_lower()
	return _search_query in msg or _search_query in src


func _get_level_color(level: int) -> Color:
	match level:
		0, 1: # TRACE, DEBUG
			return Color(0.6, 0.6, 0.6)
		2: # INFO
			return Color(0.3, 0.7, 1.0)
		3: # WARNING
			return Color(1.0, 0.8, 0.2)
		4, 5: # ERROR, FATAL
			return Color(1.0, 0.35, 0.35)
		_:
			return Color.WHITE


## === Event Handlers =========================================================

func _on_entry_added(_entry: Dictionary) -> void:
	_update_counts_label()
	_populate_tree()


func _on_count_changed(_counts: Dictionary) -> void:
	_update_counts_label()


func _on_search_changed(new_text: String) -> void:
	set_search_query(new_text)


func _on_tree_item_selected() -> void:
	if tree == null:
		return
	var selected := tree.get_selected()
	if selected == null:
		return
	var entry: Dictionary = selected.get_metadata(0) as Dictionary
	_selected_entry = entry
	_update_detail_panel(entry)
	entry_selected.emit(entry)


func navigate_to_source_for_entry(entry: Dictionary) -> void:
	var source: String = entry.get("source", "") as String
	var line_no := 1
	var last_colon := source.rfind(":")
	if last_colon > 0:
		var line_str := source.substr(last_colon + 1)
		if line_str.is_valid_int():
			line_no = line_str.to_int()
			source = source.substr(0, last_colon)
	source_navigated.emit(source, line_no)



func _on_tree_item_activated() -> void:
	if tree == null:
		return
	var selected := tree.get_selected()
	if selected == null:
		return
	var entry: Dictionary = selected.get_metadata(0) as Dictionary
	navigate_to_source_for_entry(entry)



func _update_counts_label() -> void:
	if lbl_counts == null or DiagnosticsService == null:
		return
	var errs: int = DiagnosticsService.get_count(4) + DiagnosticsService.get_count(5)
	var warns: int = DiagnosticsService.get_count(3)
	var infos: int = DiagnosticsService.get_count(2)
	lbl_counts.text = "Errors: %d | Warnings: %d | Info: %d" % [errs, warns, infos]


func _update_detail_panel(entry: Dictionary) -> void:
	if lbl_detail == null:
		return
	var lvl_name: String = (entry.get("level_name", "info") as String).to_upper()
	var src: String = entry.get("source", "N/A") as String
	var msg: String = entry.get("message", "") as String
	var frame: int = entry.get("frame", 0) as int
	lbl_detail.text = "[%s] Source: %s (Frame %d)\nMessage: %s" % [lvl_name, src, frame, msg]


func _update_filter_button_states() -> void:
	if btn_all != null:
		btn_all.button_pressed = (_active_level_filter.size() >= 5)
