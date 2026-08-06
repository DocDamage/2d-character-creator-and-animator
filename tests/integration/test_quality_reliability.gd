# Integration tests for Phase 7 recovery, performance, accessibility, and release-safety workflows.
extends Node

const RecoveryBrowserScript = preload("res://quality/recovery/recovery_browser_model.gd")
const ProfilerScript = preload("res://quality/performance/performance_profiler.gd")
const ThumbnailQueueScript = preload("res://quality/performance/lazy_thumbnail_queue.gd")
const StressSuiteScript = preload("res://quality/performance/large_project_stress_suite.gd")
const AccessibilityAuditScript = preload("res://quality/accessibility/accessibility_audit.gd")
const SecurityAuditScript = preload("res://quality/security/security_audit.gd")
const BackupManagerScript = preload("res://core/documents/backup_manager.gd")
const ProjectSchemaScript = preload("res://core/documents/project_schema.gd")


func run_tests() -> int:
	var path := "user://phase7_quality/project.chrproj"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path).get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(ProjectSchemaScript.create_default_manifest("Phase 7"))); file.close()
	var backup := BackupManagerScript.create_backup(path)
	file = FileAccess.open(path, FileAccess.WRITE); file.store_string("corrupt"); file.close()
	var browser = RecoveryBrowserScript.new()
	var candidates: Array = browser.scan(path)
	var recovered: Dictionary = browser.restore(backup)
	var profiler = ProfilerScript.new()
	var sample: Dictionary = profiler.profile("scrub", func(): return 42)
	var chunks: Array = profiler.plan_progressive_load(70, 32)
	var thumbs = ThumbnailQueueScript.new()
	var thumbnails_ok: bool = thumbs.enqueue("idle", "frame") and not thumbs.enqueue("idle", "again") and thumbs.process(1, func(payload): return str(payload) + "_thumbnail").size() == 1 and thumbs.get_cached("idle") == "frame_thumbnail"
	var stress: Dictionary = StressSuiteScript.new().run()
	var audit = AccessibilityAuditScript.new()
	var focus_root := Control.new()
	var button := Button.new(); button.focus_mode = Control.FOCUS_ALL; focus_root.add_child(button)
	var accessibility_ok: bool = audit.audit_focus(focus_root).get("valid", false) and audit.contrast_ratio(Color.WHITE, Color.BLACK) > 20.0
	var security: Dictionary = SecurityAuditScript.new().audit_release()
	if not is_instance_valid(focus_root): return 0
	focus_root.free()
	if backup != "" and candidates.size() >= 1 and recovered.get("success", false) and sample.get("value") == 42 and chunks.size() == 3 and thumbnails_ok and stress.get("characters", []).size() == 100 and accessibility_ok and SecurityAuditScript.new().is_safe_project_path("res://safe/file") and not SecurityAuditScript.new().is_safe_project_path("res://../unsafe") and security.get("valid", false):
		print("  PASS: REC/PRF/ACC reliability workflows recover safely, stay bounded, remain accessible, and audit release safety")
		return 1
	printerr("  FAIL: Phase 7 quality workflow did not meet recovery/performance/accessibility/safety expectations")
	return 0
