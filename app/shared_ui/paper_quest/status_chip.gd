class_name PaperQuestStatusChip
extends PanelContainer

const Styles = preload("res://app/shared_ui/paper_quest/paper_quest_style_factory.gd")
const Tokens = preload("res://app/shared_ui/paper_quest/paper_quest_tokens.gd")

enum Status { READY, WARNING, ERROR, INFO }

@export var status: Status = Status.READY:
	set(value):
		status = value
		_sync_status()
@export var status_text := "Ready":
	set(value):
		status_text = value
		_sync_status()

@onready var _icon: Label = get_node_or_null("Margin/Row/Icon")
@onready var _label: Label = get_node_or_null("Margin/Row/Text")

func _ready() -> void:
	custom_minimum_size.y = 28
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if ThemeService != null and not ThemeService.theme_changed.is_connected(_on_theme_changed):
		ThemeService.theme_changed.connect(_on_theme_changed)
	_sync_status()

func set_status(text: String, value: Status) -> void:
	status_text = text
	status = value
	_sync_status()

func _sync_status() -> void:
	if not is_node_ready():
		return
	var dark := ThemeService != null and ThemeService.get_theme_mode() == ThemeService.ThemeMode.DARK
	var contrast := ThemeService != null and ThemeService.is_high_contrast()
	var token: String = ["success", "warning", "error", "blue"][status]
	var icons := ["✓", "!", "×", "i"]
	var color := Tokens.color(token, dark, contrast)
	var fill := color.darkened(0.10) if dark or contrast else color.lightened(0.76)
	add_theme_stylebox_override("panel", Styles.box(fill, color, 999, 1 if not contrast else 2, 6.0))
	if _icon != null:
		_icon.text = icons[status]
		_icon.add_theme_color_override("font_color", color if not dark else Color.WHITE)
	if _label != null:
		_label.text = status_text
		_label.add_theme_color_override("font_color", Tokens.color("ink_primary", dark, contrast))
	tooltip_text = "%s status: %s" % [["Ready", "Warning", "Error", "Information"][status], status_text]

func _on_theme_changed(_mode: String, _theme: Theme) -> void:
	_sync_status()
