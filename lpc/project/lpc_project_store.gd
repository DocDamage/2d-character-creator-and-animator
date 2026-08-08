# LpcProjectStore -- Creates, opens, migrates, saves, and autosaves LPC profiles safely.
class_name LpcProjectStore
extends RefCounted

const ProjectSchemaScript = preload("res://core/documents/project_schema.gd")
const ProfileScript = preload("res://lpc/project/lpc_project_profile.gd")
const LicenseResolverScript = preload("res://lpc/licensing/lpc_license_resolver.gd")


static func create_new(path: String, options: Dictionary) -> Dictionary:
	var catalog: Dictionary = options.get("catalog", {})
	var source_lock: Dictionary = catalog.get("source_lock", {})
	var body_family_id := str(options.get("body_family_id", ""))
	var policy_id := str(options.get("policy_id", "full_source"))
	var validation := _validate_start_options(catalog, source_lock, body_family_id, policy_id)
	if not validation.is_empty(): return _failure(validation)
	var profile := ProfileScript.create({
		"label": options.get("label", "LPC Character"), "display_name_index": options.get("display_name_index", 0),
		"source_lock": source_lock, "catalog_signature": catalog.get("catalog_signature", ""),
		"source_library_root": catalog.get("source_root", ""), "policy_id": policy_id,
		"body_family_id": body_family_id, "custom_policy": options.get("custom_policy", {}),
	})
	var profile_errors := ProfileScript.validate(profile)
	if not profile_errors.is_empty(): return _failure(profile_errors)
	var manifest := ProjectSchemaScript.create_default_manifest(str(profile.label), str(profile.project_uuid))
	manifest.settings.default_facing_directions = 4
	manifest.settings.default_fps = 12
	manifest.settings.pixel_mode = true
	manifest.metadata["authoring_mode"] = "lpc_direct_start"
	manifest = ProfileScript.apply_to_manifest(manifest, profile)
	if not SerializationService.save_project(manifest, path): return _failure(["LPC project could not be saved: %s" % path])
	return {"success": true, "path": path, "manifest": manifest, "profile": profile, "errors": []}


static func open(path: String, apply_migration: bool = true) -> Dictionary:
	var manifest := SerializationService.load_project(path)
	if manifest.is_empty(): return _failure(["LPC project could not be loaded: %s" % path])
	if not ProfileScript.is_lpc_manifest(manifest): return _failure(["The selected project is not an LPC direct-start project."])
	var profile := ProfileScript.from_manifest(manifest)
	var migration := ProfileScript.migrate(profile)
	if not migration.get("success", false): return _failure(migration.get("errors", []))
	var migrated := bool(migration.get("changed", false))
	profile = migration.get("profile", {})
	var errors := ProfileScript.validate(profile)
	if not errors.is_empty(): return _failure(errors)
	var migration_backup := ""
	if migrated and apply_migration:
		migration_backup = _create_migration_backup(path)
		if migration_backup.is_empty(): return _failure(["LPC profile migration could not create a durable backup."])
		manifest = ProfileScript.apply_to_manifest(manifest, profile)
		if not SerializationService.save_project(manifest, path): return _failure(["LPC profile migration could not be saved."])
	return {"success": true, "path": path, "manifest": manifest, "profile": profile, "migrated": migrated, "migration_backup": migration_backup, "errors": []}


static func save(path: String, manifest: Dictionary, profile: Dictionary) -> Dictionary:
	var errors := ProfileScript.validate(profile)
	if not errors.is_empty(): return _failure(errors)
	var next_manifest := ProfileScript.apply_to_manifest(manifest, profile)
	next_manifest["modified_at"] = Time.get_unix_time_from_system()
	if not SerializationService.save_project(next_manifest, path): return _failure(["LPC project save failed."])
	return {"success": true, "manifest": next_manifest, "profile": profile, "path": path, "errors": []}


static func autosave(path: String, manifest: Dictionary, profile: Dictionary) -> Dictionary:
	var errors := ProfileScript.validate(profile)
	if not errors.is_empty(): return _failure(errors)
	var autosave_path := path.get_basename() + ".lpc.autosave.chrproj"
	var next_manifest := ProfileScript.apply_to_manifest(manifest, profile)
	if not SerializationService.autosave(next_manifest, autosave_path): return _failure(["LPC project autosave failed."])
	var hash := SerializationService.compute_hash(next_manifest)
	var JournalScript = preload("res://core/documents/recovery_journal.gd")
	JournalScript.record_event("autosave", autosave_path, hash)
	return {"success": true, "path": autosave_path, "hash": hash, "errors": []}


static func _validate_start_options(catalog: Dictionary, source_lock: Dictionary, body_family_id: String, policy_id: String) -> Array[String]:
	var errors: Array[String] = []
	if catalog.is_empty() or not bool(catalog.get("validation_errors", []).is_empty()): errors.append("A validated LPC catalog is required.")
	if str(source_lock.get("source_lock_signature", "")).is_empty(): errors.append("The selected catalog is missing its source-lock signature.")
	if body_family_id.is_empty(): errors.append("Choose a compatible body family.")
	if LicenseResolverScript.profile(policy_id).is_empty(): errors.append("Choose a valid license policy profile.")
	var viable := false
	for asset_id in (catalog.get("assets", {}) as Dictionary):
		var asset: Dictionary = catalog.assets[asset_id]
		if body_family_id not in asset.get("body_family_ids", []): continue
		if str(asset.get("type_name", "")).to_lower() not in ["body", "base", "body_base"]: continue
		if LicenseResolverScript.resolve_asset(asset, policy_id).get("success", false): viable = true; break
	if not viable: errors.append("The selected policy has no viable base body for '%s'." % body_family_id)
	return errors


static func _failure(errors: Array) -> Dictionary:
	var messages: Array[String] = []
	for error in errors: messages.append(str(error))
	return {"success": false, "errors": messages}


static func _create_migration_backup(path: String) -> String:
	if not FileAccess.file_exists(path): return ""
	var absolute_path := ProjectSettings.globalize_path(path) if path.begins_with("res://") or path.begins_with("user://") else path
	var suffix := ".lpc-migration-%d.bak" % Time.get_unix_time_from_system()
	var target := absolute_path + suffix
	var index := 2
	while FileAccess.file_exists(target):
		target = absolute_path + suffix + "." + str(index)
		index += 1
	return target if DirAccess.copy_absolute(absolute_path, target) == OK else ""
