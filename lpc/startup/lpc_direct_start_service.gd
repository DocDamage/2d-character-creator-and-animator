# LpcDirectStartService -- Phase-1 library location, cache, project creation, and resume policy.
class_name LpcDirectStartService
extends RefCounted

const NameSequenceScript = preload("res://lpc/project/lpc_name_sequence.gd")
const CatalogBuilderScript = preload("res://lpc/catalog/lpc_catalog_builder.gd")
const ProjectStoreScript = preload("res://lpc/project/lpc_project_store.gd")
const ProfileScript = preload("res://lpc/project/lpc_project_profile.gd")
const STATE_PATH := NameSequenceScript.STATE_PATH


static func library_root() -> String:
	return str(NameSequenceScript.load_state(STATE_PATH).get("library_root", ""))


static func set_library_root(path: String) -> Dictionary:
	var root := _absolute(path).simplify_path()
	if root.is_empty() or not DirAccess.dir_exists_absolute(root): return _failure(["Choose an existing LPC library folder."])
	var state := NameSequenceScript.load_state(STATE_PATH)
	state["library_root"] = root
	if not NameSequenceScript.save_state(state, STATE_PATH): return _failure(["LPC library location could not be saved."])
	return {"success": true, "root": root, "errors": []}


static func rebuild_catalog() -> Dictionary:
	var root := library_root()
	if root.is_empty(): return _failure(["Locate a locked local LPC library before rebuilding its catalog."])
	var previous := CatalogBuilderScript.load_cache(root)
	var built := CatalogBuilderScript.build(root)
	if not built.get("success", false): return built
	var cached := CatalogBuilderScript.write_cache(built.catalog)
	if not cached.get("success", false): return cached
	var state := NameSequenceScript.load_state(STATE_PATH)
	state["catalog_signature"] = str(built.catalog.get("catalog_signature", ""))
	state["catalog_cached_at"] = Time.get_unix_time_from_system()
	NameSequenceScript.save_state(state, STATE_PATH)
	return {"success": true, "catalog": built.catalog, "cache_path": cached.path, "diff": CatalogBuilderScript.diff(previous.get("catalog", {}), built.catalog) if previous.get("success", false) else {}, "errors": []}


static func catalog() -> Dictionary:
	var root := library_root()
	if root.is_empty(): return _failure(["No LPC library has been located."])
	return CatalogBuilderScript.load_cache(root)


static func library_status() -> Dictionary:
	var root := library_root()
	if root.is_empty(): return {"available": false, "root": "", "actions": ["Locate library", "Open non-LPC project"], "message": "Locate a local, locked LPC source library to begin."}
	var cached := catalog()
	if not cached.get("success", false): return {"available": false, "root": root, "actions": ["Rebuild catalog", "Locate library", "Open non-LPC project"], "message": str(cached.get("errors", ["Catalog needs rebuilding."])[0])}
	return {"available": true, "root": root, "catalog_signature": str(cached.catalog.get("catalog_signature", "")), "actions": ["Rebuild catalog", "Open non-LPC project"], "message": "Locked catalog ready."}


static func compatible_body_families(policy_id: String) -> Array[Dictionary]:
	var cached := catalog()
	if not cached.get("success", false): return []
	var catalog_data: Dictionary = cached.catalog
	var families: Array[Dictionary] = []
	for raw_family in catalog_data.get("body_families", []):
		var family: Dictionary = (raw_family as Dictionary).duplicate(true) if raw_family is Dictionary else {"id": str(raw_family), "name": str(raw_family)}
		var validation := ProjectStoreScript._validate_start_options(catalog_data, catalog_data.get("source_lock", {}), str(family.get("id", "")), policy_id)
		family["eligible"] = validation.is_empty()
		family["reason"] = "" if validation.is_empty() else str(validation[0])
		families.append(family)
	return families


static func create_project(path: String, label: String, body_family_id: String, policy_id: String) -> Dictionary:
	var cached := catalog()
	if not cached.get("success", false): return cached
	var created := ProjectStoreScript.create_new(path, {"catalog": cached.catalog, "label": label, "body_family_id": body_family_id, "policy_id": policy_id})
	if created.get("success", false) and RecentProjectsService != null: RecentProjectsService.add_project(path, label)
	return created


static func latest_resumable() -> Dictionary:
	if RecentProjectsService == null: return _failure(["Recent project service is unavailable."])
	for raw_entry in RecentProjectsService.get_recent_projects():
		var entry: Dictionary = raw_entry
		if not bool(entry.get("exists", false)): continue
		var opened := ProjectStoreScript.open(str(entry.get("path", "")), false)
		if opened.get("success", false): return opened
	return _failure(["No resumable LPC project was found."])


static func _absolute(path: String) -> String:
	return ProjectSettings.globalize_path(path) if path.begins_with("res://") or path.begins_with("user://") else path


static func _failure(errors: Array) -> Dictionary:
	var messages: Array[String] = []
	for error in errors: messages.append(str(error))
	return {"success": false, "errors": messages}
