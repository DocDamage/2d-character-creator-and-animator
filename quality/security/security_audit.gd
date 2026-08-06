# SecurityAudit -- Path, plugin-boundary, encoder, and license-manifest checks for release candidates.
class_name SecurityAudit
extends RefCounted


func is_safe_project_path(path: String) -> bool:
	return not path.strip_edges().is_empty() and not path.contains("..") and (path.begins_with("res://") or path.begins_with("user://"))


func safe_plugin_call(plugin: Variant, method: String, arguments: Array = []) -> Dictionary:
	if plugin == null or not plugin.has_method(method): return {"success": false, "error": "plugin method is unavailable"}
	return {"success": true, "value": plugin.callv(method, arguments)}


func audit_release(encoder: String = "ffmpeg") -> Dictionary:
	var output: Array = []
	var encoder_ok := OS.execute(encoder, ["-version"], output, true, false) == 0
	var licenses_ok := FileAccess.file_exists("res://docs/architecture/ASSET_LICENSES.md") and FileAccess.file_exists("res://docs/architecture/DEPENDENCY_LICENSES.md")
	return {"valid": encoder_ok and licenses_ok, "encoder_ok": encoder_ok, "licenses_ok": licenses_ok, "encoder": encoder}
