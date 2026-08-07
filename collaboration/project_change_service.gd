# ProjectChangeService -- Git-friendly, deterministic project diffs and snapshot comparison guidance.
class_name ProjectChangeService
extends RefCounted


func diff(before: Dictionary, after: Dictionary) -> Dictionary:
	var changes: Array = []
	_collect_changes(before, after, "", changes)
	return {"changed": not changes.is_empty(), "changes": changes, "summary": _summary(changes), "asset_changes": _asset_changes(before, after)}


func compare_snapshot(session, snapshot_id: String) -> Dictionary:
	if session == null or not is_instance_valid(session): return {"success": false, "errors": ["Open a project before comparing snapshots."]}
	var snapshot: Dictionary = session.get_project_snapshot(snapshot_id)
	if snapshot.is_empty(): return {"success": false, "errors": ["The selected snapshot is unavailable."]}
	var saved := _load_manifest(str(snapshot.get("project_path", "")))
	if saved.is_empty(): return {"success": false, "errors": ["The selected snapshot could not be read."]}
	var report := diff(saved, session.get_manifest_copy())
	report["success"] = true
	report["snapshot"] = snapshot
	return report


func conflict_guidance(base: Dictionary, local: Dictionary, incoming: Dictionary) -> Dictionary:
	var local_paths := _paths(diff(base, local).get("changes", []) as Array)
	var incoming_paths := _paths(diff(base, incoming).get("changes", []) as Array)
	var conflicts: Array = []
	for path in local_paths:
		if incoming_paths.has(path): conflicts.append({"path": path, "guidance": _guidance_for_path(path)})
	return {"has_conflicts": not conflicts.is_empty(), "conflicts": conflicts, "safe_local_paths": _difference(local_paths, incoming_paths), "safe_incoming_paths": _difference(incoming_paths, local_paths)}


func git_status(project_path: String) -> Dictionary:
	var output: Array = []
	var root := _absolute(project_path).get_base_dir()
	var code := OS.execute("git", ["-C", root, "status", "--short"], output, true)
	return {"available": code == 0, "status": "\n".join(_strings(output)), "exit_code": code, "root": root}


func _collect_changes(before: Variant, after: Variant, path: String, output: Array) -> void:
	if typeof(before) != typeof(after): output.append({"path": _path(path), "kind": "changed_type", "before": before, "after": after}); return
	if before is Dictionary:
		var keys: Array = (before as Dictionary).keys()
		for key in (after as Dictionary).keys():
			if key not in keys: keys.append(key)
		keys.sort()
		for key in keys:
			var has_before := (before as Dictionary).has(key)
			var has_after := (after as Dictionary).has(key)
			var child_path := path + "." + str(key) if not path.is_empty() else str(key)
			if not has_before: output.append({"path": child_path, "kind": "added", "after": (after as Dictionary)[key]})
			elif not has_after: output.append({"path": child_path, "kind": "removed", "before": (before as Dictionary)[key]})
			else: _collect_changes((before as Dictionary)[key], (after as Dictionary)[key], child_path, output)
	elif before is Array:
		if JSON.stringify(before, "", true, false) != JSON.stringify(after, "", true, false): output.append({"path": _path(path), "kind": "changed_array", "before_count": (before as Array).size(), "after_count": (after as Array).size()})
	elif before != after:
		output.append({"path": _path(path), "kind": "changed", "before": before, "after": after})


func _asset_changes(before: Dictionary, after: Dictionary) -> Array:
	var left: Dictionary = before.get("objects", {}).get("assets", {}) as Dictionary
	var right: Dictionary = after.get("objects", {}).get("assets", {}) as Dictionary
	var ids: Array = left.keys()
	for asset_id in right: if asset_id not in ids: ids.append(asset_id)
	ids.sort()
	var result: Array = []
	for asset_id in ids:
		if not left.has(asset_id): result.append({"asset_id": asset_id, "kind": "added", "path": str((right[asset_id] as Dictionary).get("path", ""))})
		elif not right.has(asset_id): result.append({"asset_id": asset_id, "kind": "removed", "path": str((left[asset_id] as Dictionary).get("path", ""))})
		elif JSON.stringify(left[asset_id], "", true, false) != JSON.stringify(right[asset_id], "", true, false): result.append({"asset_id": asset_id, "kind": "changed", "before_path": str((left[asset_id] as Dictionary).get("path", "")), "after_path": str((right[asset_id] as Dictionary).get("path", "")), "checksum_changed": str((left[asset_id] as Dictionary).get("checksum", "")) != str((right[asset_id] as Dictionary).get("checksum", ""))})
	return result


func _summary(changes: Array) -> Dictionary:
	var result := {"added": 0, "removed": 0, "changed": 0}
	for change in changes:
		match str((change as Dictionary).get("kind", "changed")):
			"added": result["added"] += 1
			"removed": result["removed"] += 1
			_: result["changed"] += 1
	return result


func _paths(changes: Array) -> Dictionary:
	var result: Dictionary = {}
	for change in changes: result[str((change as Dictionary).get("path", ""))] = true
	return result


func _difference(left: Dictionary, right: Dictionary) -> Array:
	var result: Array = []
	for path in left:
		if not right.has(path): result.append(path)
	result.sort()
	return result


func _guidance_for_path(path: String) -> String:
	if path.begins_with("objects.assets"): return "Choose one artwork revision, then re-run import preflight before resolving."
	if path.contains("tracks") or path.contains("animations"): return "Keep both timeline edits only when their key times differ; otherwise choose a source and review the motion diff."
	if path.contains("production_suite"): return "Merge authored parameters by stable ID, then validate the runtime contract."
	return "Compare the two values, resolve deliberately, then run validation before committing."


func _load_manifest(path: String) -> Dictionary:
	var absolute := _absolute(path)
	if absolute.is_empty() or not FileAccess.file_exists(absolute): return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(absolute))
	return parsed as Dictionary if parsed is Dictionary else {}


func _path(value: String) -> String: return value if not value.is_empty() else "$"
func _strings(values: Array) -> Array:
	var result: Array = []
	for value in values: result.append(str(value))
	return result
func _absolute(path: String) -> String: return ProjectSettings.globalize_path(path) if path.begins_with("res://") or path.begins_with("user://") else path
