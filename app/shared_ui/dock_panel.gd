# Dock Panel — Dockable container UI element for application shell
# Extends PanelContainer to support panel titles, docking state, and collapse operations
class_name DockPanel
extends PanelContainer

signal dock_region_changed(panel_id: String, new_region: String)
signal collapse_toggled(panel_id: String, is_collapsed: bool)
signal closed(panel_id: String)

enum DockRegion {
	LEFT,
	RIGHT,
	BOTTOM,
	CENTER
}

@export var panel_id: String = "panel_default"
@export var panel_title: String = "Dock Panel":
	set = set_panel_title
@export var current_region: DockRegion = DockRegion.LEFT

var _is_collapsed: bool = false
var _header_bar: HBoxContainer = null
var _title_label: Label = null
var _content_container: MarginContainer = null
var _collapse_button: Button = null
var _context_state: Control = null

func _init() -> void:
	custom_minimum_size = Vector2(180, 120)

func _ready() -> void:
	_build_layout_if_needed()
	# The surrounding TabContainer already names the active tool. Keep only a
	# compact collapse affordance so the title is not repeated inside the panel.
	if get_parent() is TabContainer and _header_bar != null:
		_title_label.text = ""
		_header_bar.custom_minimum_size.y = 28
		_collapse_button.custom_minimum_size = Vector2(28, 28)
	_sync_tab_title()

func set_panel_title(p_title: String) -> void:
	panel_title = p_title
	if _title_label != null:
		_title_label.text = panel_title
	_sync_tab_title()

func get_panel_id() -> String:
	return panel_id

func set_dock_region(region: DockRegion) -> void:
	if current_region != region:
		current_region = region
		var region_str := _region_to_string(region)
		dock_region_changed.emit(panel_id, region_str)

func get_dock_region_string() -> String:
	return _region_to_string(current_region)

func toggle_collapse() -> void:
	_is_collapsed = not _is_collapsed
	if _content_container != null:
		_content_container.visible = not _is_collapsed
	if _collapse_button != null:
		_collapse_button.text = "+" if _is_collapsed else "-"
	collapse_toggled.emit(panel_id, _is_collapsed)

func is_collapsed() -> bool:
	return _is_collapsed

func get_content_container() -> MarginContainer:
	_build_layout_if_needed()
	return _content_container

func add_content(node: Control) -> void:
	var container := get_content_container()
	if container != null and node != null:
		if _context_state != null and is_instance_valid(_context_state):
			container.remove_child(_context_state)
			_context_state.queue_free()
			_context_state = null
		container.add_child(node)

func serialize_state() -> Dictionary:
	var panel_visible := visible
	if get_parent() is TabContainer:
		panel_visible = not (get_parent() as TabContainer).is_tab_hidden(get_index())
	return {
		"panel_id": panel_id,
		"panel_title": panel_title,
		"region": _region_to_string(current_region),
		"collapsed": _is_collapsed,
		"visible": panel_visible
	}

func deserialize_state(data: Dictionary) -> void:
	if data.has("panel_title"):
		set_panel_title(data["panel_title"] as String)
	if data.has("region"):
		current_region = _string_to_region(data["region"] as String)
	if data.has("collapsed"):
		var should_collapse: bool = data["collapsed"] as bool
		if should_collapse != _is_collapsed:
			toggle_collapse()
	if data.has("visible"):
		if get_parent() is TabContainer:
			var tabs := get_parent() as TabContainer
			tabs.set_tab_hidden(get_index(), not (data["visible"] as bool))
			var has_visible_tab := false
			for index in tabs.get_tab_count():
				if not tabs.is_tab_hidden(index): has_visible_tab = true; break
			tabs.visible = has_visible_tab
		else:
			visible = data["visible"] as bool

func _build_layout_if_needed() -> void:
	if get_child_count() > 0 and _content_container != null:
		return

	var main_box := VBoxContainer.new()
	main_box.name = "MainVBox"
	main_box.add_theme_constant_override("separation", 8)
	add_child(main_box)

	_header_bar = HBoxContainer.new()
	_header_bar.name = "HeaderBar"
	_header_bar.custom_minimum_size.y = 40
	main_box.add_child(_header_bar)

	_title_label = Label.new()
	_title_label.name = "TitleLabel"
	_title_label.text = panel_title
	_title_label.theme_type_variation = &"SectionLabel"
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_header_bar.add_child(_title_label)

	_collapse_button = Button.new()
	_collapse_button.name = "CollapseButton"
	_collapse_button.text = "-"
	_collapse_button.tooltip_text = "Collapse / Expand Panel"
	_collapse_button.custom_minimum_size = Vector2(28, 28)
	_collapse_button.theme_type_variation = &"GhostButton"
	_collapse_button.pressed.connect(toggle_collapse)
	_header_bar.add_child(_collapse_button)

	_content_container = MarginContainer.new()
	_content_container.name = "ContentContainer"
	_content_container.add_theme_constant_override("margin_left", 6)
	_content_container.add_theme_constant_override("margin_top", 6)
	_content_container.add_theme_constant_override("margin_right", 6)
	_content_container.add_theme_constant_override("margin_bottom", 6)
	_content_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_box.add_child(_content_container)
	_add_context_state_if_needed()


func _add_context_state_if_needed() -> void:
	var messages := {
		"panel_hierarchy": "No rig selected\nChoose a character rig to inspect its hierarchy.",
		"panel_viewport": "No canvas document selected\nOpen a rig or animation to edit it here.",
		"panel_inspector": "Nothing selected\nSelect an authored object to inspect its properties.",
		"panel_timeline": "No animation selected\nOpen or create an animation to edit its timeline.",
	}
	if not messages.has(panel_id): return
	var state := CenterContainer.new()
	_context_state = state
	state.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	state.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var label := Label.new()
	label.text = messages[panel_id]
	label.custom_minimum_size.x = 150.0
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.theme_type_variation = &"MutedLabel"
	state.add_child(label)
	_content_container.add_child(state)


func _sync_tab_title() -> void:
	if get_parent() is TabContainer:
		var tabs := get_parent() as TabContainer
		var tab_index := get_index()
		if tab_index >= 0 and tab_index < tabs.get_tab_count():
			tabs.set_tab_title(tab_index, panel_title)

func _region_to_string(region: DockRegion) -> String:
	match region:
		DockRegion.LEFT: return "LEFT"
		DockRegion.RIGHT: return "RIGHT"
		DockRegion.BOTTOM: return "BOTTOM"
		DockRegion.CENTER: return "CENTER"
		_: return "LEFT"

func _string_to_region(region_str: String) -> DockRegion:
	match region_str.to_upper():
		"LEFT": return DockRegion.LEFT
		"RIGHT": return DockRegion.RIGHT
		"BOTTOM": return DockRegion.BOTTOM
		"CENTER": return DockRegion.CENTER
		_: return DockRegion.LEFT
