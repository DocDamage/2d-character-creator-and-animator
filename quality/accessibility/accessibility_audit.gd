# AccessibilityAudit -- Focus/label and color-contrast checks with persisted visual-preference data.
class_name AccessibilityAudit
extends RefCounted

var reduced_motion: bool = false
var high_contrast: bool = false


func set_preferences(reduced: bool, contrast: bool) -> void:
	reduced_motion = reduced
	high_contrast = contrast


func audit_focus(root: Node) -> Dictionary:
	var missing: Array = []
	_collect_focus_issues(root, missing)
	return {"valid": missing.is_empty(), "missing_focus": missing}


func contrast_ratio(foreground: Color, background: Color) -> float:
	var light := _luminance(foreground)
	var dark := _luminance(background)
	return (maxf(light, dark) + 0.05) / (minf(light, dark) + 0.05)


func to_dict() -> Dictionary: return {"reduced_motion": reduced_motion, "high_contrast": high_contrast}
func from_dict(data: Dictionary) -> AccessibilityAudit:
	reduced_motion = bool(data.get("reduced_motion", false)); high_contrast = bool(data.get("high_contrast", false)); return self


func _collect_focus_issues(node: Node, output: Array) -> void:
	if node is Button or node is LineEdit or node is SpinBox or node is OptionButton:
		var control := node as Control
		if control.focus_mode == Control.FOCUS_NONE: output.append(control.get_path())
	for child in node.get_children(): _collect_focus_issues(child, output)


func _luminance(color: Color) -> float:
	var linear := Color(color.r, color.g, color.b).srgb_to_linear()
	return 0.2126 * linear.r + 0.7152 * linear.g + 0.0722 * linear.b
