@tool
extends SceneTree

# Generate Studio Theme — Programmatically generates default_theme.tres
# Run headlessly via: godot --headless --script tools/theme_generator/generate_studio_theme.gd

const THEME_PATH := "res://app/shared_ui/default_theme.tres"

func _init() -> void:
	print("[ThemeGenerator] Building modern Studio UI Theme...")
	var theme := Theme.new()

	# Base Colors
	var bg_obsidian := Color("#121319")
	var bg_panel := Color("#1A1C24")
	var bg_header := Color("#232633")
	var border_subtle := Color("#2E3345")
	var accent_cyan := Color("#00E5FF")
	var accent_magenta := Color("#FF007F")
	var text_main := Color("#E6E9EE")
	var text_muted := Color("#8B94A5")

	# PanelContainer Style
	var sb_panel := StyleBoxFlat.new()
	sb_panel.bg_color = bg_panel
	sb_panel.border_color = border_subtle
	sb_panel.set_border_width_all(1)
	sb_panel.set_corner_radius_all(6)
	sb_panel.content_margin_left = 6
	sb_panel.content_margin_top = 6
	sb_panel.content_margin_right = 6
	sb_panel.content_margin_bottom = 6
	theme.set_stylebox("panel", "PanelContainer", sb_panel)

	# Button Styles
	var sb_btn_normal := StyleBoxFlat.new()
	sb_btn_normal.bg_color = bg_header
	sb_btn_normal.border_color = border_subtle
	sb_btn_normal.set_border_width_all(1)
	sb_btn_normal.set_corner_radius_all(4)
	sb_btn_normal.content_margin_left = 10
	sb_btn_normal.content_margin_top = 6
	sb_btn_normal.content_margin_right = 10
	sb_btn_normal.content_margin_bottom = 6

	var sb_btn_hover := sb_btn_normal.duplicate() as StyleBoxFlat
	sb_btn_hover.bg_color = Color("#2A2F40")
	sb_btn_hover.border_color = accent_cyan

	var sb_btn_pressed := sb_btn_normal.duplicate() as StyleBoxFlat
	sb_btn_pressed.bg_color = Color("#00A3B8")
	sb_btn_pressed.border_color = accent_cyan

	theme.set_stylebox("normal", "Button", sb_btn_normal)
	theme.set_stylebox("hover", "Button", sb_btn_hover)
	theme.set_stylebox("pressed", "Button", sb_btn_pressed)
	theme.set_color("font_color", "Button", text_main)
	theme.set_color("font_hover_color", "Button", accent_cyan)

	# GhostButton Variation
	var sb_ghost := StyleBoxFlat.new()
	sb_ghost.bg_color = Color.TRANSPARENT
	sb_ghost.set_corner_radius_all(4)
	sb_ghost.content_margin_left = 6
	sb_ghost.content_margin_top = 4
	sb_ghost.content_margin_right = 6
	sb_ghost.content_margin_bottom = 4
	theme.set_stylebox("normal", "GhostButton", sb_ghost)
	theme.set_stylebox("hover", "GhostButton", sb_btn_hover)

	# TabContainer Styles
	var sb_tab_selected := StyleBoxFlat.new()
	sb_tab_selected.bg_color = bg_panel
	sb_tab_selected.border_color = accent_cyan
	sb_tab_selected.set_border_width_all(1)
	sb_tab_selected.border_width_bottom = 3
	sb_tab_selected.set_corner_radius_all(4)
	sb_tab_selected.content_margin_left = 12
	sb_tab_selected.content_margin_top = 6
	sb_tab_selected.content_margin_right = 12
	sb_tab_selected.content_margin_bottom = 6

	var sb_tab_unselected := StyleBoxFlat.new()
	sb_tab_unselected.bg_color = bg_obsidian
	sb_tab_unselected.border_color = border_subtle
	sb_tab_unselected.set_border_width_all(1)
	sb_tab_unselected.set_corner_radius_all(4)
	sb_tab_unselected.content_margin_left = 12
	sb_tab_unselected.content_margin_top = 6
	sb_tab_unselected.content_margin_right = 12
	sb_tab_unselected.content_margin_bottom = 6

	theme.set_stylebox("tab_selected", "TabContainer", sb_tab_selected)
	theme.set_stylebox("tab_unselected", "TabContainer", sb_tab_unselected)

	# Label Colors
	theme.set_color("font_color", "Label", text_main)
	theme.set_color("font_color", "SectionLabel", accent_cyan)

	# Save theme to file
	var err := ResourceSaver.save(theme, THEME_PATH)
	if err == OK:
		print("[ThemeGenerator] Successfully generated theme at: ", THEME_PATH)
	else:
		print("[ThemeGenerator] Error saving theme: ", err)
	quit()
