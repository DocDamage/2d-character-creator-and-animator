# LinkedProjectService -- Deterministic shared-asset links, overrides, conflict repair, and packages.
class_name LinkedProjectService
extends RefCounted

const SCHEMA_VERSION := "1.0.0"

var links: Dictionary = {}
var overrides: Dictionary = {}
var conflicts: Dictionary = {}


func link_project(link_id: String, project_id: String, source_path: String, resources: Dictionary, revision: int = 1) -> bool:
	if link_id.strip_edges().is_empty() or project_id.strip_edges().is_empty() or links.has(link_id):
		return false
	links[link_id] = {"link_id": link_id, "project_id": project_id, "source_path": source_path, "revision": maxi(1, revision), "resources": resources.duplicate(true), "status": "linked"}
	return true


func register_shared_resource(link_id: String, asset_id: String, resource_type: String, data: Dictionary) -> bool:
	if not links.has(link_id) or asset_id.strip_edges().is_empty() or resource_type not in ["rig", "character", "accessory"]:
		return false
	var resources: Dictionary = links[link_id].get("resources", {})
	resources[asset_id] = {"asset_id": asset_id, "resource_type": resource_type, "data": data.duplicate(true)}
	links[link_id]["resources"] = resources
	return true


func set_local_override(link_id: String, asset_id: String, patch: Dictionary) -> bool:
	var source := _source_resource(link_id, asset_id)
	if source.is_empty() or patch.is_empty():
		return false
	overrides[_key(link_id, asset_id)] = {"link_id": link_id, "asset_id": asset_id, "base_revision": int(links[link_id].get("revision", 1)), "patch": patch.duplicate(true)}
	return true


func get_resource(link_id: String, asset_id: String) -> Dictionary:
	var source := _source_resource(link_id, asset_id)
	if source.is_empty():
		return {}
	var override: Dictionary = overrides.get(_key(link_id, asset_id), {})
	return _merge(source, override.get("patch", {}) as Dictionary) if not override.is_empty() else source


func refresh_link(link_id: String, incoming_resources: Dictionary, revision: int) -> Dictionary:
	if not links.has(link_id):
		return {"success": false, "errors": ["unknown link"]}
	var link: Dictionary = links[link_id]
	var old_resources: Dictionary = link.get("resources", {})
	var report := {"success": true, "changed": [], "missing": [], "conflicts": []}
	for asset_id in old_resources:
		if not incoming_resources.has(asset_id):
			(report["missing"] as Array).append(asset_id)
	for asset_id in incoming_resources:
		var old: Dictionary = old_resources.get(asset_id, {})
		var incoming: Dictionary = incoming_resources[asset_id]
		if old != incoming:
			(report["changed"] as Array).append(asset_id)
			var override: Dictionary = overrides.get(_key(link_id, asset_id), {})
			if not override.is_empty() and int(override.get("base_revision", 0)) < revision:
				var conflict := {"link_id": link_id, "asset_id": asset_id, "base": old, "remote": incoming, "local_patch": override.get("patch", {})}
				conflicts[_key(link_id, asset_id)] = conflict
				(report["conflicts"] as Array).append(conflict.duplicate(true))
	link["resources"] = incoming_resources.duplicate(true)
	link["revision"] = maxi(int(link.get("revision", 1)), revision)
	link["status"] = "broken" if not (report["missing"] as Array).is_empty() else "linked"
	links[link_id] = link
	return report


func get_conflicts(link_id: String = "") -> Array:
	var output: Array = []
	for conflict in conflicts.values():
		if link_id.is_empty() or str((conflict as Dictionary).get("link_id", "")) == link_id:
			output.append((conflict as Dictionary).duplicate(true))
	return output


func resolve_conflict(link_id: String, asset_id: String, strategy: String, merged_patch: Dictionary = {}) -> bool:
	var key := _key(link_id, asset_id)
	if not conflicts.has(key) or strategy not in ["keep_local", "use_remote", "merge"]:
		return false
	if strategy == "use_remote":
		overrides.erase(key)
	else:
		var patch: Dictionary = overrides.get(key, {}).get("patch", {})
		if strategy == "merge": patch = merged_patch
		overrides[key] = {"link_id": link_id, "asset_id": asset_id, "base_revision": int(links[link_id].get("revision", 1)), "patch": patch.duplicate(true)}
	conflicts.erase(key)
	return true


func package_dependencies(requests: Array) -> Dictionary:
	var assets: Array = []
	var missing: Array = []
	for request in requests:
		var record := request as Dictionary
		var resource := get_resource(str(record.get("link_id", "")), str(record.get("asset_id", "")))
		if resource.is_empty(): missing.append(record.duplicate(true))
		else: assets.append(resource)
	return {"schema_version": SCHEMA_VERSION, "assets": assets, "missing": missing, "valid": missing.is_empty()}


func preview_multi_character(instances: Array) -> Dictionary:
	var characters: Array = []
	var missing: Array = []
	for instance in instances:
		var record := instance as Dictionary
		var resource := get_resource(str(record.get("link_id", "")), str(record.get("asset_id", "")))
		if resource.is_empty() or str(resource.get("resource_type", "")) != "character":
			missing.append(record.duplicate(true))
			continue
		characters.append({"character": resource, "position": record.get("position", [0.0, 0.0]), "facing": record.get("facing", "right")})
	return {"characters": characters, "missing": missing, "valid": missing.is_empty()}


func validate() -> Array:
	var errors: Array = []
	for link_id in links:
		var link: Dictionary = links[link_id]
		if str(link.get("project_id", "")).is_empty(): errors.append("link " + str(link_id) + " has no project id")
		if str(link.get("status", "")) == "broken": errors.append("link " + str(link_id) + " has missing dependencies")
	return errors


func to_dict() -> Dictionary:
	return {"schema_version": SCHEMA_VERSION, "links": links.duplicate(true), "overrides": overrides.duplicate(true), "conflicts": conflicts.duplicate(true)}


func from_dict(data: Dictionary) -> LinkedProjectService:
	links = (data.get("links", {}) as Dictionary).duplicate(true)
	overrides = (data.get("overrides", {}) as Dictionary).duplicate(true)
	conflicts = (data.get("conflicts", {}) as Dictionary).duplicate(true)
	return self


func _source_resource(link_id: String, asset_id: String) -> Dictionary:
	return (links.get(link_id, {}) as Dictionary).get("resources", {}).get(asset_id, {}) as Dictionary


func _key(link_id: String, asset_id: String) -> String:
	return link_id + "::" + asset_id


func _merge(base: Dictionary, patch: Dictionary) -> Dictionary:
	var result := base.duplicate(true)
	for key in patch:
		if result.get(key) is Dictionary and patch[key] is Dictionary: result[key] = _merge(result[key], patch[key])
		else: result[key] = patch[key]
	return result
