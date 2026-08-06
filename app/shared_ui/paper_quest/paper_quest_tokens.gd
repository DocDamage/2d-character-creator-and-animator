class_name PaperQuestTokens
extends RefCounted

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

const DARK_COLORS := {
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
	"purple": Color("#FF007F"),
	"purple_dark": Color("#C70063"),
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
	if high_contrast and HIGH_CONTRAST_COLORS.has(token):
		return HIGH_CONTRAST_COLORS[token]
	if dark_craft and DARK_COLORS.has(token):
		return DARK_COLORS[token]
	return COLORS.get(token, Color.MAGENTA)

static func workspace_color(workspace_id: String, dark_craft: bool = false, high_contrast: bool = false) -> Color:
	var token := {
		"project_assets": "red",
		"character_creator": "orange",
		"rigging_deformation": "green",
		"animation_studio": "blue",
		"weapon_equipment": "orange_dark",
		"preview_export": "purple",
	}.get(workspace_id, "blue") as String
	return color(token, dark_craft, high_contrast)
