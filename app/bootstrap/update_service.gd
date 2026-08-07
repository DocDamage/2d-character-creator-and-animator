# UpdateService -- Manifest-based update checks suitable for portable and installer distributions.
extends Node

signal update_check_completed(result: Dictionary)

const BUNDLED_MANIFEST := "res://release/update_manifest.json"
const SETTINGS_PATH := "user://update_settings.json"

var _feed_url := ""
var _channel := "stable"
var _last_result: Dictionary = {}


func _ready() -> void:
	_load_settings()


func configure_feed(url: String, channel: String = "stable") -> void:
	_feed_url = url.strip_edges()
	_channel = channel.strip_edges() if not channel.strip_edges().is_empty() else "stable"
	_save_settings()


func get_last_result() -> Dictionary:
	return _last_result.duplicate(true)


func open_available_update() -> bool:
	var url := str(_last_result.get("download_url", "")).strip_edges()
	if url.is_empty() or not (url.begins_with("https://") or url.begins_with("http://")):
		return false
	return OS.shell_open(url) == OK


func check_bundled_manifest() -> Dictionary:
	var result := _read_manifest(BUNDLED_MANIFEST)
	result["source"] = "bundled"
	_finish(result)
	return result


func check_for_updates() -> Dictionary:
	if _feed_url.is_empty():
		return check_bundled_manifest()
	if not (_feed_url.begins_with("https://") or _feed_url.begins_with("http://")):
		var local_result := _read_manifest(_feed_url)
		local_result["source"] = "configured_local"
		_finish(local_result)
		return local_result
	var request := HTTPRequest.new()
	add_child(request)
	request.request_completed.connect(func(result_code, response_code, _headers, body):
		var result := _parse_remote_response(result_code, response_code, body)
		request.queue_free()
		_finish(result)
	)
	var error := request.request(_feed_url)
	if error != OK:
		request.queue_free()
		var failed := {"success": false, "update_available": false, "message": "Could not start the update check.", "error": error, "source": "remote"}
		_finish(failed)
		return failed
	return {"success": true, "pending": true, "update_available": false, "message": "Checking for updates…", "source": "remote"}


func _read_manifest(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"success": false, "update_available": false, "message": "No update manifest is configured for this build."}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null: return {"success": false, "update_available": false, "message": "Update manifest could not be read."}
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	return _evaluate_manifest(parsed)


func _parse_remote_response(result_code: int, response_code: int, body: PackedByteArray) -> Dictionary:
	if result_code != HTTPRequest.RESULT_SUCCESS or response_code < 200 or response_code >= 300:
		return {"success": false, "update_available": false, "message": "Update server did not return a valid response.", "response_code": response_code}
	return _evaluate_manifest(JSON.parse_string(body.get_string_from_utf8()))


func _evaluate_manifest(data: Variant) -> Dictionary:
	if not data is Dictionary:
		return {"success": false, "update_available": false, "message": "Update manifest is invalid."}
	var manifest: Dictionary = data
	var version := str(manifest.get("version", ""))
	if version.is_empty(): return {"success": false, "update_available": false, "message": "Update manifest has no version."}
	var current := str(ProjectSettings.get_setting("application/config/version", "0.0.0"))
	var available := _compare_versions(version, current) > 0
	return {"success": true, "update_available": available, "current_version": current, "version": version, "download_url": str(manifest.get("download_url", "")), "notes": str(manifest.get("notes", "")), "message": "Update %s is available." % version if available else "You are up to date (%s)." % current}


func _compare_versions(left: String, right: String) -> int:
	var a := left.trim_prefix("v").split("-", false)[0].split(".")
	var b := right.trim_prefix("v").split("-", false)[0].split(".")
	for index in range(max(a.size(), b.size())):
		var av := int(a[index]) if index < a.size() else 0
		var bv := int(b[index]) if index < b.size() else 0
		if av != bv: return 1 if av > bv else -1
	return 0


func _finish(result: Dictionary) -> void:
	_last_result = result.duplicate(true)
	update_check_completed.emit(_last_result)


func _load_settings() -> void:
	if not FileAccess.file_exists(SETTINGS_PATH): return
	var file := FileAccess.open(SETTINGS_PATH, FileAccess.READ)
	if file == null: return
	var data = JSON.parse_string(file.get_as_text())
	file.close()
	if data is Dictionary:
		_feed_url = str((data as Dictionary).get("feed_url", ""))
		_channel = str((data as Dictionary).get("channel", "stable"))


func _save_settings() -> void:
	var file := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify({"feed_url": _feed_url, "channel": _channel}))
		file.close()
