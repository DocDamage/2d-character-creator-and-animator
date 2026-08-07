class_name PaperQuestTokens
extends RefCounted

enum Palette { OBSIDIAN, PAPER_QUEST, DARK_CRAFT, HIGH_CONTRAST }

const COLORS := {
	"paper_base": Color("#F3E6D2"),
	"paper_top": Color("#FAF1E2"),
	"paper_muted": Color("#E8D7BA"),
	"paper_dark": Color("#D5C19E"),
	"cardboard_base": Color("#B98652"),
	"cardboard_light": Color("#D2A873"),
	"cardboard_dark": Color("#6B4729"),
	"cardboard_edge": Color("#8E6038"),
	"ink_primary": Color("#382E1E"),
	"ink_muted": Color("#766650"),
	"blue": Color("#2E6FA7"),
	"blue_dark": Color("#1E527B"),
	"green": Color("#5E8E3E"),
	"green_dark": Color("#3E672A"),
	"red": Color("#C84E3A"),
	"red_dark": Color("#933526"),
	"orange": Color("#E09A28"),
	"orange_dark": Color("#A86B18"),
	"purple": Color("#7A5AA6"),
	"purple_dark": Color("#563C7A"),
	"success": Color("#5B8F45"),
	"warning": Color("#D58A28"),
	"error": Color("#C84E3A"),
	"focus": Color("#3C8CD2"),
}

const OBSIDIAN_COLORS := {
	"paper_base": Color("#121319"),
	"paper_top": Color("#1A1C24"),
	"paper_muted": Color("#232633"),
	"paper_dark": Color("#0E0F14"),
	"cardboard_base": Color("#1A1C24"),
	"cardboard_light": Color("#232633"),
	"cardboard_dark": Color("#0E0F14"),
	"cardboard_edge": Color("#2E3345"),
	"ink_primary": Color("#E6E9EE"),
	"ink_muted": Color("#8B94A5"),
	"blue": Color("#00E5FF"),
	"blue_dark": Color("#00A3B8"),
	"green": Color("#39D98A"),
	"green_dark": Color("#219A63"),
	"red": Color("#FF5C7A"),
	"red_dark": Color("#C73552"),
	"orange": Color("#FFB547"),
	"orange_dark": Color("#C77D1D"),
	"purple": Color("#FF007F"),
	"purple_dark": Color("#C70063"),
	"success": Color("#39D98A"),
	"warning": Color("#FFB547"),
	"error": Color("#FF5C7A"),
	"focus": Color("#00E5FF"),
}

const DARK_COLORS := {
	"paper_base": Color("#34291F"),
	"paper_top": Color("#4B3B2B"),
	"paper_muted": Color("#3E3025"),
	"paper_dark": Color("#2A211A"),
	"cardboard_base": Color("#201A15"),
	"cardboard_light": Color("#4A3525"),
	"cardboard_dark": Color("#120F0C"),
	"cardboard_edge": Color("#6B4729"),
	"ink_primary": Color("#FFF4DC"),
	"ink_muted": Color("#D8C7A5"),
}

const HIGH_CONTRAST_COLORS := {
	"paper_base": Color("#101010"),
	"paper_top": Color("#181818"),
	"paper_muted": Color("#222222"),
	"paper_dark": Color("#000000"),
	"cardboard_base": Color("#000000"),
	"cardboard_light": Color("#111111"),
	"cardboard_dark": Color("#000000"),
	"cardboard_edge": Color.WHITE,
	"ink_primary": Color.WHITE,
	"ink_muted": Color("#E8E8E8"),
	"blue": Color("#58B4FF"),
	"blue_dark": Color("#58B4FF"),
	"green": Color("#8DE56C"),
	"green_dark": Color("#8DE56C"),
	"red": Color("#FF6B58"),
	"red_dark": Color("#FF6B58"),
	"orange": Color("#FFC04D"),
	"orange_dark": Color("#FFC04D"),
	"purple": Color("#C799FF"),
	"purple_dark": Color("#C799FF"),
	"success": Color("#8DE56C"),
	"warning": Color("#FFC04D"),
	"error": Color("#FF6B58"),
	"focus": Color("#58B4FF"),
}

const SPACING := {"xxs": 4, "xs": 8, "sm": 12, "md": 16, "lg": 24, "xl": 32, "xxl": 48}
const RADII := {"xs": 3, "sm": 6, "md": 10, "lg": 16, "pill": 999}
const DIMENSIONS := {
	"top_navigation_height": 72,
	"status_bar_height": 34,
	"left_region_width": 270,
	"right_region_width": 320,
	"button_height": 40,
	"field_height": 34,
	"minimum_target": 40,
	"focus_stroke": 3,
}

static func color(token: String, dark_craft: bool = false, high_contrast: bool = false) -> Color:
	var palette := Palette.HIGH_CONTRAST if high_contrast else (Palette.DARK_CRAFT if dark_craft else Palette.PAPER_QUEST)
	return color_for_palette(token, palette)

static func color_for_palette(token: String, palette: int) -> Color:
	var palette_colors: Dictionary
	match palette:
		Palette.OBSIDIAN:
			palette_colors = OBSIDIAN_COLORS
		Palette.DARK_CRAFT:
			palette_colors = DARK_COLORS
		Palette.HIGH_CONTRAST:
			palette_colors = HIGH_CONTRAST_COLORS
		_:
			palette_colors = COLORS
	if palette_colors.has(token):
		return palette_colors[token]
	return COLORS.get(token, Color.MAGENTA)

static func workspace_color(workspace_id: String, dark_craft: bool = false, high_contrast: bool = false) -> Color:
	var palette := Palette.HIGH_CONTRAST if high_contrast else (Palette.DARK_CRAFT if dark_craft else Palette.PAPER_QUEST)
	return workspace_color_for_palette(workspace_id, palette)

static func workspace_color_for_palette(workspace_id: String, palette: int) -> Color:
	var token := {
		"project_assets": "red",
		"character_creator": "orange",
		"rigging_deformation": "green",
		"animation_studio": "blue",
		"weapon_equipment": "orange_dark",
		"preview_export": "purple",
	}.get(workspace_id, "blue") as String
	return color_for_palette(token, palette)
