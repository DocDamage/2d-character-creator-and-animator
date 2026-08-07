class_name PaperButton
extends Button

enum Style { PRIMARY, SECONDARY, TERTIARY, DESTRUCTIVE, GHOST }

@export var style: Style = Style.TERTIARY:
	set(value):
		style = value
		_sync_style()

func _ready() -> void:
	custom_minimum_size.x = maxf(custom_minimum_size.x, 40.0)
	custom_minimum_size.y = maxf(custom_minimum_size.y, 40.0)
	focus_mode = Control.FOCUS_ALL
	_sync_style()

func _sync_style() -> void:
	theme_type_variation = {
		Style.PRIMARY: &"PrimaryButton",
		Style.SECONDARY: &"SecondaryButton",
		Style.TERTIARY: &"Button",
		Style.DESTRUCTIVE: &"DestructiveButton",
		Style.GHOST: &"GhostButton",
	}.get(style, &"Button")
