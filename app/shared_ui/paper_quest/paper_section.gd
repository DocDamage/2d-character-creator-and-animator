class_name PaperSection
extends VBoxContainer

const Styles = preload("res://app/shared_ui/paper_quest/paper_quest_style_factory.gd")
const Tokens = preload("res://app/shared_ui/paper_quest/paper_quest_tokens.gd")

@export_enum("blue", "green", "orange", "red", "purple") var accent := "blue"
@export var raised := true

func _ready() -> void:
	resized.connect(queue_redraw)
	if ThemeService != null and not ThemeService.theme_changed.is_connected(_on_theme_changed):
		ThemeService.theme_changed.connect(_on_theme_changed)
	queue_redraw()

func _draw() -> void:
	var contrast := ThemeService != null and ThemeService.is_high_contrast()
	var background := _token("paper_top")
	var edge := _token("cardboard_edge")
	draw_style_box(Styles.paper(background, edge, contrast, raised), Rect2(Vector2.ZERO, size))
	draw_rect(Rect2(0, 0, size.x, 5), _token(accent), true)

func _on_theme_changed(_mode: String, _theme: Theme) -> void:
	queue_redraw()

func _token(name: String) -> Color:
	return ThemeService.get_color_token(name) if ThemeService != null else Tokens.color(name)
