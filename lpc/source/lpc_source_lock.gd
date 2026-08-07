# LpcSourceLock -- Loads and validates the immutable, pinned LPC source lock.
class_name LpcSourceLock
extends RefCounted

const LOCK_FILE_NAME := "lpc_source.lock.json"
const REQUIRED_FIELDS := [
	"lock_schema_version", "upstream_repository_url", "upstream_commit_sha",
	"catalog_adapter_version", "accepted_source_tree_paths", "expected_root_hashes",
	"palette_policy_version", "layout_policy_version", "license_policy_version",
	"build_timestamp", "build_tool_version", "catalog_signature",
]


static func load_file(path: String) -> Dictionary:
	if path.strip_edges().is_empty() or not FileAccess.file_exists(path):
		return _failure(["LPC source lock is missing: %s" % path])
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return _failure(["LPC source lock could not be read: %s" % path])
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	if not (parsed is Dictionary):
		return _failure(["LPC source lock is not a JSON object: %s" % path])
	var lock: Dictionary = (parsed as Dictionary).duplicate(true)
	var errors := validate(lock)
	if not errors.is_empty():
		return _failure(errors)
	lock["source_lock_signature"] = signature(lock)
	return {"success": true, "lock": lock, "errors": []}


static func validate(lock: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	for field in REQUIRED_FIELDS:
		if not lock.has(field):
			errors.append("LPC source lock is missing '%s'." % field)
	for field in ["upstream_repository_url", "upstream_commit_sha", "catalog_adapter_version"]:
		if str(lock.get(field, "")).strip_edges().is_empty():
			errors.append("LPC source lock field '%s' cannot be empty." % field)
	if not str(lock.get("upstream_repository_url", "")).begins_with("https://"):
		errors.append("LPC source lock must record an HTTPS upstream URL.")
	if str(lock.get("upstream_commit_sha", "")).length() < 12:
		errors.append("LPC source lock must record a commit SHA.")
	if not lock.get("accepted_source_tree_paths", []) is Array:
		errors.append("accepted_source_tree_paths must be an array.")
	else:
		for entry in lock.get("accepted_source_tree_paths", []):
			var clean := str(entry).replace("\\", "/").strip_edges()
			if clean.is_empty() or clean.begins_with("/") or ":" in clean or ".." in clean.split("/"):
				errors.append("Unsafe accepted source path: %s" % entry)
	if not lock.get("expected_root_hashes", {}) is Dictionary:
		errors.append("expected_root_hashes must be an object.")
	if str(lock.get("catalog_signature", "")).strip_edges().is_empty():
		errors.append("LPC source lock must carry a catalog signature marker.")
	return errors


static func signature(lock: Dictionary) -> String:
	var copy := lock.duplicate(true)
	copy.erase("catalog_signature")
	copy.erase("source_lock_signature")
	return _canonical_json(copy).sha256_text()


static func validate_source_root(lock: Dictionary, source_root: String) -> Array[String]:
	var errors: Array[String] = []
	var root := _absolute(source_root)
	if root.is_empty() or not DirAccess.dir_exists_absolute(root):
		return ["LPC source root is unavailable: %s" % source_root]
	var expected_hashes: Dictionary = lock.get("expected_root_hashes", {})
	for pair in expected_hashes:
		var relative := str(pair)
		var expected := str(expected_hashes[pair])
		var target := root.path_join(relative)
		if not FileAccess.file_exists(target):
			errors.append("Locked source file is missing: %s" % relative)
			continue
		var actual := _file_sha256(target)
		if not expected.is_empty() and actual != expected:
			errors.append("Locked source hash mismatch: %s" % relative)
	return errors


static func _file_sha256(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	var bytes := file.get_buffer(file.get_length())
	file.close()
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(bytes)
	return context.finish().hex_encode()


static func _absolute(path: String) -> String:
	return ProjectSettings.globalize_path(path) if path.begins_with("res://") or path.begins_with("user://") else path


static func _canonical_json(value: Variant) -> String:
	return JSON.stringify(_canonicalize(value), "", false)


static func _canonicalize(value: Variant) -> Variant:
	if value is Dictionary:
		var keys := (value as Dictionary).keys()
		keys.sort()
		var result := {}
		for key in keys:
			result[key] = _canonicalize((value as Dictionary)[key])
		return result
	if value is Array:
		var result: Array = []
		for item in value:
			result.append(_canonicalize(item))
		return result
	if value is float:
		var snapped: float = round(float(value))
		return int(snapped) if is_equal_approx(float(value), snapped) else value
	return value


static func _failure(errors: Array[String]) -> Dictionary:
	return {"success": false, "lock": {}, "errors": errors}
