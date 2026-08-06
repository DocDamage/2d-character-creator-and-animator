class_name PaperQuestThemeBuilder
extends RefCounted

const Tokens = preload("res://app/shared_ui/paper_quest/paper_quest_tokens.gd")
const Styles = preload("res://app/shared_ui/paper_quest/paper_quest_style_factory.gd")

static func build(dark_craft: bool, high_contrast: bool) -> Theme:
	var theme := Theme.new()
	var paper := Tokens.color("paper_base", dark_craft, high_contrast)
	var top := Tokens.color("paper_top", dark_craft, high_contrast)
	var muted_paper := Tokens.color("paper_muted", dark_craft, high_contrast)
	var dark_paper := Tokens.color("paper_dark", dark_craft, high_contrast)
	var cardboard := Tokens.color("cardboard_base", dark_craft, high_contrast)
	var cardboard_light := Tokens.color("cardboard_light", dark_craft, high_contrast)
	var cardboard_dark := Tokens.color("cardboard_dark", dark_craft, high_contrast)
	var edge := Tokens.color("cardboard_edge", dark_craft, high_contrast)
	var ink := Tokens.color("ink_primary", dark_craft, high_contrast)
	var muted := Tokens.color("ink_muted", dark_craft, high_contrast)
	var blue := Tokens.color("blue", dark_craft, high_contrast)
	var focus := Tokens.color("focus", dark_craft, high_contrast)

	_setup_fonts(theme, ink, muted)
	_setup_panels(theme, paper, top, muted_paper, cardboard, cardboard_light, cardboard_dark, edge, high_contrast)
	_setup_buttons(theme, paper, top, muted_paper, dark_paper, edge, ink, muted, focus, dark_craft, high_contrast)
	_setup_fields(theme, top, muted_paper, edge, ink, muted, focus)
	_setup_lists_and_tabs(theme, paper, top, muted_paper, edge, ink, muted, blue, focus, high_contrast)
	_setup_misc(theme, paper, top, muted_paper, dark_paper, edge, ink, muted, blue, focus)
	return theme

static func _setup_fonts(theme: Theme, ink: Color, muted: Color) -> void:
	var body_font := SystemFont.new()
	body_font.font_names = PackedStringArray(["Nunito Sans", "Nunito", "Segoe UI"])
	var heading_font := SystemFont.new()
	heading_font.font_names = PackedStringArray(["Nunito Sans", "Nunito", "Segoe UI Semibold"])
	heading_font.font_weight = 700
	var display_font := SystemFont.new()
	display_font.font_names = PackedStringArray(["Baloo 2", "Fredoka", "Nunito Sans", "Segoe UI Semibold"])
	display_font.font_weight = 700
	theme.default_font = body_font
	theme.default_font_size = 13
	for type_name in ["Label", "Button", "OptionButton", "LineEdit", "TextEdit", "SpinBox", "CheckBox", "CheckButton", "Tree", "ItemList", "RichTextLabel", "PopupMenu", "MenuBar", "TabBar", "TabContainer"]:
		theme.set_color("font_color", type_name, ink)
		theme.set_color("font_hover_color", type_name, ink)
		theme.set_color("font_pressed_color", type_name, ink)
		theme.set_color("font_focus_color", type_name, ink)
		theme.set_color("font_disabled_color", type_name, muted.darkened(0.12))
	_register_label(theme, "DisplayLabel", display_font, 30, ink)
	_register_label(theme, "H1Label", heading_font, 24, ink)
	_register_label(theme, "H2Label", heading_font, 18, ink)
	_register_label(theme, "SectionLabel", heading_font, 13, ink)
	_register_label(theme, "MutedLabel", body_font, 12, muted)
	_register_label(theme, "CaptionLabel", body_font, 11, muted)
	_register_label(theme, "BrandTitle", display_font, 18, ink)
	_register_label(theme, "BrandSubtitle", heading_font, 10, muted)
	_register_label(theme, "StatusBarLabel", body_font, 11, Color("#FFF4DC"))

static func _register_label(theme: Theme, variation: StringName, font: Font, size: int, color: Color) -> void:
	theme.set_type_variation(variation, &"Label")
	theme.set_font("font", variation, font)
	theme.set_font_size("font_size", variation, size)
	theme.set_color("font_color", variation, color)

static func _setup_panels(theme: Theme, paper: Color, top: Color, muted_paper: Color, cardboard: Color, cardboard_light: Color, cardboard_dark: Color, edge: Color, high_contrast: bool) -> void:
	theme.set_stylebox("panel", "Panel", Styles.paper(paper, edge, high_contrast, false))
	theme.set_stylebox("panel", "PanelContainer", Styles.paper(paper, edge, high_contrast, true))
	_register_panel(theme, "PaperPanel", top, edge, high_contrast, true)
	_register_panel(theme, "FlatPaperPanel", paper, edge, high_contrast, false)
	_register_panel(theme, "MutedPaperPanel", muted_paper, edge, high_contrast, false)
	_register_panel(theme, "CardboardPanel", cardboard, edge, high_contrast, true)
	_register_panel(theme, "TopNavigation", cardboard_light, edge, high_contrast, true)
	_register_panel(theme, "StatusBar", cardboard_dark, edge, high_contrast, false)
	_register_panel(theme, "GuidePanel", top, Tokens.color("green", false, high_contrast), high_contrast, true)

static func _register_panel(theme: Theme, variation: StringName, background: Color, border: Color, high_contrast: bool, raised: bool) -> void:
	theme.set_type_variation(variation, &"PanelContainer")
	theme.set_stylebox("panel", variation, Styles.paper(background, border, high_contrast, raised))

static func _setup_buttons(theme: Theme, paper: Color, top: Color, muted_paper: Color, dark_paper: Color, edge: Color, ink: Color, muted: Color, focus: Color, dark_craft: bool, high_contrast: bool) -> void:
	_register_button(theme, "Button", top, muted_paper, dark_paper, edge, ink, muted, focus, high_contrast)
	_register_button(theme, "PrimaryButton", Tokens.color("blue", dark_craft, high_contrast), Tokens.color("blue", dark_craft, high_contrast).lightened(0.09), Tokens.color("blue_dark", dark_craft, high_contrast), Tokens.color("blue_dark", dark_craft, high_contrast), Color.WHITE, muted, focus, high_contrast)
	_register_button(theme, "SecondaryButton", Tokens.color("green", dark_craft, high_contrast), Tokens.color("green", dark_craft, high_contrast).lightened(0.08), Tokens.color("green_dark", dark_craft, high_contrast), Tokens.color("green_dark", dark_craft, high_contrast), Color.WHITE, muted, focus, high_contrast)
	_register_button(theme, "DestructiveButton", Tokens.color("red", dark_craft, high_contrast), Tokens.color("red", dark_craft, high_contrast).lightened(0.08), Tokens.color("red_dark", dark_craft, high_contrast), Tokens.color("red_dark", dark_craft, high_contrast), Color.WHITE, muted, focus, high_contrast)
	_register_button(theme, "GhostButton", Color.TRANSPARENT, paper, muted_paper, Color.TRANSPARENT, ink, muted, focus, high_contrast)
	_register_workspace_tabs(theme, top, muted_paper, dark_paper, edge, ink, muted, focus, dark_craft, high_contrast)
	for type_name in ["Button", "OptionButton", "CheckBox", "CheckButton"]:
		theme.set_constant("outline_size", type_name, 0)

static func _register_button(theme: Theme, variation: StringName, normal: Color, hover: Color, pressed: Color, border: Color, text: Color, disabled_text: Color, focus: Color, high_contrast: bool) -> void:
	if variation not in [&"Button", &"OptionButton"]:
		theme.set_type_variation(variation, &"Button")
	var border_width := 2 if high_contrast else 1
	theme.set_stylebox("normal", variation, Styles.box(normal, border, 6, border_width, 11.0, Color(0.12, 0.07, 0.03, 0.24) if not high_contrast else Color.TRANSPARENT, 3 if not high_contrast else 0, Vector2(0, 2)))
	theme.set_stylebox("hover", variation, Styles.box(hover, border, 6, border_width, 11.0, Color(0.12, 0.07, 0.03, 0.34) if not high_contrast else Color.TRANSPARENT, 4 if not high_contrast else 0, Vector2(0, 2)))
	theme.set_stylebox("pressed", variation, Styles.box(pressed, border, 6, border_width, 11.0, Color(0.10, 0.05, 0.02, 0.18), 1, Vector2(0, 1)))
	theme.set_stylebox("focus", variation, Styles.focus(normal, focus, 7))
	theme.set_stylebox("disabled", variation, Styles.box(normal.lerp(Color.GRAY, 0.38), border.lerp(Color.GRAY, 0.35), 6, border_width, 11.0))
	theme.set_color("font_color", variation, text)
	theme.set_color("font_hover_color", variation, text)
	theme.set_color("font_pressed_color", variation, text)
	theme.set_color("font_focus_color", variation, text)
	theme.set_color("font_disabled_color", variation, disabled_text)
	theme.set_font_size("font_size", variation, 13)

static func _register_workspace_tabs(theme: Theme, top: Color, hover: Color, pressed: Color, edge: Color, ink: Color, muted: Color, focus: Color, dark_craft: bool, high_contrast: bool) -> void:
	_register_button(theme, "WorkspaceTab", top, hover, pressed, edge, ink, muted, focus, high_contrast)
	var variants := {
		"WorkspaceTabProject": "red",
		"WorkspaceTabCreate": "orange",
		"WorkspaceTabRig": "green",
		"WorkspaceTabAnimate": "blue",
		"WorkspaceTabWeapon": "orange_dark",
		"WorkspaceTabExport": "purple",
	}
	for variation in variants:
		var active := Tokens.color(variants[variation], dark_craft, high_contrast)
		_register_button(theme, variation, active, active.lightened(0.08), active.darkened(0.12), active.darkened(0.22), Color.WHITE, muted, focus, high_contrast)

static func _setup_fields(theme: Theme, top: Color, read_only: Color, edge: Color, ink: Color, muted: Color, focus: Color) -> void:
	for type_name in ["LineEdit", "TextEdit"]:
		theme.set_stylebox("normal", type_name, Styles.line(top, edge, focus))
		theme.set_stylebox("focus", type_name, Styles.line(top, edge, focus, true))
		theme.set_stylebox("read_only", type_name, Styles.line(read_only, edge, focus))
		theme.set_color("font_color", type_name, ink)
		theme.set_color("font_placeholder_color", type_name, muted)
		theme.set_color("font_uneditable_color", type_name, muted)
		theme.set_color("caret_color", type_name, focus)
		theme.set_color("selection_color", type_name, focus.darkened(0.20))
	_register_button(theme, "OptionButton", top, top.lightened(0.04), read_only, edge, ink, muted, focus, false)

static func _setup_lists_and_tabs(theme: Theme, paper: Color, top: Color, selected: Color, edge: Color, ink: Color, muted: Color, blue: Color, focus: Color, high_contrast: bool) -> void:
	for type_name in ["ItemList", "Tree"]:
		theme.set_stylebox("panel", type_name, Styles.box(top, edge, 7, 2 if high_contrast else 1, 7.0))
		theme.set_stylebox("selected", type_name, Styles.box(blue, blue.darkened(0.2), 5, 1, 5.0))
		theme.set_stylebox("selected_focus", type_name, Styles.box(blue, focus, 5, 3, 5.0))
		theme.set_stylebox("cursor", type_name, Styles.focus(Color.TRANSPARENT, focus, 5))
		theme.set_color("font_color", type_name, ink)
		theme.set_color("font_selected_color", type_name, Color.WHITE)
	theme.set_stylebox("panel", "TabContainer", Styles.paper(paper, edge, high_contrast, false))
	theme.set_stylebox("tab_selected", "TabContainer", Styles.box(top, blue, 6, 2, 9.0))
	theme.set_stylebox("tab_unselected", "TabContainer", Styles.box(selected, edge, 6, 1, 9.0))
	theme.set_stylebox("tab_hovered", "TabContainer", Styles.box(top, edge, 6, 1, 9.0))
	theme.set_stylebox("tab_focus", "TabContainer", Styles.focus(Color.TRANSPARENT, focus, 6))
	theme.set_color("font_selected_color", "TabContainer", ink)
	theme.set_color("font_unselected_color", "TabContainer", muted)
	theme.set_color("font_hovered_color", "TabContainer", ink)

static func _setup_misc(theme: Theme, paper: Color, top: Color, muted_paper: Color, dark_paper: Color, edge: Color, ink: Color, muted: Color, blue: Color, focus: Color) -> void:
	theme.set_stylebox("panel", "GraphEdit", Styles.box(top, edge, 8, 1, 8.0))
	theme.set_stylebox("panel", "GraphNode", Styles.paper(paper, edge, false, true))
	theme.set_stylebox("titlebar", "GraphNode", Styles.box(muted_paper, edge, 6, 1, 6.0))
	theme.set_stylebox("panel", "PopupMenu", Styles.paper(top, edge, false, true))
	theme.set_stylebox("hover", "PopupMenu", Styles.box(muted_paper, blue, 4, 1, 5.0))
	theme.set_stylebox("background", "ProgressBar", Styles.box(dark_paper, edge, 999, 1, 2.0))
	theme.set_stylebox("fill", "ProgressBar", Styles.box(blue, blue.darkened(0.2), 999, 0, 2.0))
	theme.set_stylebox("panel", "TooltipPanel", Styles.box(ink, edge, 5, 1, 8.0, Color(0, 0, 0, 0.35), 4, Vector2(0, 2)))
	theme.set_color("font_color", "TooltipLabel", top)
	theme.set_color("font_color", "RichTextLabel", ink)
	theme.set_color("default_color", "RichTextLabel", ink)
	for container_type in ["HBoxContainer", "VBoxContainer", "GridContainer"]:
		theme.set_constant("separation", container_type, 8)
	theme.set_constant("separation", "HSplitContainer", 8)
	theme.set_constant("separation", "VSplitContainer", 8)
	theme.set_constant("minimum_grab_thickness", "HScrollBar", 12)
	theme.set_constant("minimum_grab_thickness", "VScrollBar", 12)
