# QualityDashboardPanel -- Recovery browsing, stress checks, accessibility preferences, and release safety.
class_name QualityDashboardPanel
extends Control

const RecoveryScript = preload("res://quality/recovery/recovery_browser_model.gd")
const StressScript = preload("res://quality/performance/large_project_stress_suite.gd")
const AccessibilityScript = preload("res://quality/accessibility/accessibility_audit.gd")
const SecurityScript = preload("res://quality/security/security_audit.gd")

@onready var project_path: LineEdit = $Margin/Root/ProjectPath
@onready var output: RichTextLabel = $Margin/Root/Output
@onready var status_label: Label = $Margin/Root/Status
@onready var reduced_motion: CheckBox = $Margin/Root/Preferences/ReducedMotion
@onready var high_contrast: CheckBox = $Margin/Root/Preferences/HighContrast

var recovery = RecoveryScript.new()
var accessibility = AccessibilityScript.new()
var candidates: Array = []


func _ready() -> void:
	if ThemeService != null:
		reduced_motion.set_pressed_no_signal(ThemeService.is_reduced_motion())
		high_contrast.set_pressed_no_signal(ThemeService.is_high_contrast())
	$Margin/Root/Actions/Scan.pressed.connect(_on_scan)
	$Margin/Root/Actions/Recover.pressed.connect(_on_recover)
	$Margin/Root/Actions/Audit.pressed.connect(_on_audit)
	reduced_motion.toggled.connect(_on_preferences_changed)
	high_contrast.toggled.connect(_on_preferences_changed)
	_refresh("Enter a project path to inspect recovery and release quality.")


func bind_project_path(path: String) -> void:
	project_path.text = path


func _on_scan() -> void:
	candidates = recovery.scan(project_path.text.strip_edges())
	output.text = "Recovery candidates: %d" % candidates.size()
	_refresh("Recovery candidates scanned.")


func _on_recover() -> void:
	if candidates.is_empty(): _refresh("Scan for recovery candidates first."); return
	var result: Dictionary = recovery.restore(str((candidates[0] as Dictionary).get("path", "")))
	_refresh(str(result.get("message", "Recovery did not complete.")))


func _on_audit() -> void:
	var stress: Dictionary = StressScript.new().run()
	var safety: Dictionary = SecurityScript.new().audit_release()
	output.text = "Stress characters: %d\nRelease safety: %s\nAccessibility: %s" % [stress.get("characters", []).size(), str(safety.get("valid", false)), str(accessibility.to_dict())]
	_refresh("Quality audit completed.")


func _on_preferences_changed(_value: bool) -> void:
	accessibility.set_preferences(reduced_motion.button_pressed, high_contrast.button_pressed)
	if ThemeService != null:
		ThemeService.call("set_reduced_motion", reduced_motion.button_pressed)
		ThemeService.call("set_high_contrast", high_contrast.button_pressed)


func _refresh(message: String) -> void:
	if status_label == null: return
	var lower := message.to_lower()
	var is_error := "did not" in lower or "first" in lower or "failed" in lower
	var is_success := "completed" in lower or "scanned" in lower or "restored" in lower
	status_label.text = ("× " if is_error else ("✓ " if is_success else "i ")) + message
	if ThemeService != null:
		status_label.add_theme_color_override("font_color", ThemeService.get_color_token("error" if is_error else ("success" if is_success else "blue")))
