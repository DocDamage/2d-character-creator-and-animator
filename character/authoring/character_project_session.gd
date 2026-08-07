# CharacterProjectSession -- Loads, edits, imports, and persists one character project.
class_name CharacterProjectSession
extends Node

const FactoryScript = preload("res://character/authoring/character_project_factory.gd")
const ModelScript = preload("res://character/authoring/character_creator_model.gd")
const PartScript = preload("res://character/definitions/character_part_definition.gd")
const BodyScript = preload("res://character/definitions/character_body_type_definition.gd")
const SlotScript = preload("res://character/definitions/character_slot_definition.gd")
const PartRegistryScript = preload("res://character/registries/character_part_registry.gd")
const SlotRegistryScript = preload("res://character/registries/character_slot_registry.gd")
const AssetRegistryScript = preload("res://core/assets/asset_registry.gd")
const ThumbnailCacheScript = preload("res://core/assets/thumbnail_cache.gd")
const ImageImporterScript = preload("res://core/assets/image_importer.gd")
const RecoveryJournalScript = preload("res://core/documents/recovery_journal.gd")
const MissingFileRepairScript = preload("res://core/assets/missing_file_repair.gd")
const AssetReportsScript = preload("res://core/assets/asset_reports.gd")

signal session_changed(description: String)
signal project_saved(path: String)

var project_path := ""
var manifest: Dictionary = {}
var active_character_id := ""
var model = null
var part_registry = PartRegistryScript.new()
var slot_registry = SlotRegistryScript.new()
var asset_registry = AssetRegistryScript.new()
var thumbnail_cache = ThumbnailCacheScript.new()
var body_types: Array = []
var _slot_order: Array[String] = []
var last_autosave_unix: int = 0
var _restoring_document := false

func _ready() -> void:
	if asset_registry.get_parent() == null: add_child(asset_registry)
	if thumbnail_cache.get_parent() == null: add_child(thumbnail_cache)


func open_project(path: String) -> Dictionary:
	var loaded: Dictionary = SerializationService.load_project(path)
	if loaded.is_empty(): return _failure("The project file is invalid or could not be read.")
	project_path = path
	manifest = loaded.duplicate(true)
	_ensure_authoring_data()
	_hydrate_registries()
	var report := _hydrate_character()
	if not report.get("success", false): return report
	model.set_history_recorder(Callable(self, "_record_model_history"))
	model.changed.connect(_on_model_changed)
	return {"success": true, "errors": []}


func import_part(source_path: String, slot_id: String, display_name: String = "") -> Dictionary:
	if is_read_only(): return _failure("Bundled samples are read-only. Use Save As before importing artwork.")
	if model == null or not slot_registry.has_slot(slot_id):
		return _failure("Choose a valid layer slot before importing art.")
	var inspection := ImageImporterScript.inspect_image(source_path)
	if not inspection.get("valid", false): return _failure(str(inspection.get("error", "Image import failed.")))
	var part_id: String = IDService.generate_id("prt")
	var copied_path := _copy_into_project(source_path, part_id)
	if copied_path.is_empty(): return _failure("The image could not be copied into the project assets folder.")
	var asset: Dictionary = ImageImporterScript.import_image(copied_path, asset_registry)
	if asset.is_empty() or not asset.has("asset_id"): return _failure("The imported image could not be registered.")
	var duplicate_asset_ids := _duplicate_asset_ids(str(asset.get("checksum", "")), str(asset.get("asset_id", "")))
	var name := display_name.strip_edges()
	if name.is_empty(): name = source_path.get_file().get_basename().capitalize()
	var part = PartScript.new(part_id, name, slot_id)
	part.asset_id = str(asset.get("asset_id", ""))
	part.supported_body_type_ids = [model.assembly.body_type_id]
	part.metadata = {"source": "imported", "layer_index": _slot_order.find(slot_id)}
	if not part_registry.register_part(part): return _failure("The imported image could not be added as a character part.")
	asset_registry.update_asset(part.asset_id, {
		"tags": ["character_part", slot_id],
		"metadata": {"character_part_id": part_id, "slot_id": slot_id},
	})
	var equip_report: Dictionary = model.equip_part(part_id)
	if not equip_report.get("success", false): return equip_report
	_sync_manifest()
	return {"success": true, "errors": [], "part_id": part_id, "asset_id": part.asset_id, "path": copied_path, "duplicate_asset_ids": duplicate_asset_ids}


func set_character_name(next_name: String) -> bool:
	var clean_name := next_name.strip_edges()
	if model == null or clean_name.is_empty() or model.assembly.display_name == clean_name: return false
	if is_read_only(): return false
	var before := _capture_document_snapshot()
	model.assembly.display_name = clean_name
	manifest.project_name = clean_name
	_commit_document_edit(before, "Renamed Character")
	return true


func is_read_only() -> bool:
	return project_path.begins_with("res://")


func get_canvas_settings() -> Dictionary:
	var authoring: Dictionary = manifest.get("metadata", {}).get("character_authoring", {})
	var canvas: Dictionary = authoring.get("canvas", {})
	return {
		"width": clampi(int(canvas.get("width", 512)), 16, 8192),
		"height": clampi(int(canvas.get("height", 512)), 16, 8192),
		"pixel_scale": clampf(float(canvas.get("pixel_scale", 1.0)), 0.25, 16.0),
	}


func set_canvas_settings(width: int, height: int, pixel_scale: float) -> bool:
	if model == null or is_read_only(): return false
	var next := {"width": clampi(width, 16, 8192), "height": clampi(height, 16, 8192), "pixel_scale": clampf(pixel_scale, 0.25, 16.0)}
	if next == get_canvas_settings(): return false
	var before := _capture_document_snapshot()
	var authoring: Dictionary = manifest.metadata.get("character_authoring", {}).duplicate(true)
	authoring["canvas"] = next
	manifest.metadata["character_authoring"] = authoring
	_commit_document_edit(before, "Changed Canvas Settings")
	return true


func get_slot_template_options() -> Array:
	return FactoryScript.get_slot_template_options()


func get_selected_slot_template() -> String:
	return str(manifest.get("metadata", {}).get("template_id", "blank"))


func apply_slot_template(template_id: String) -> Dictionary:
	if model == null: return _failure("Open a character project before choosing a slot template.")
	if is_read_only(): return _failure("Bundled samples are read-only. Use Save As before changing templates.")
	if not model.assembly.get_equipped_part_ids().is_empty() or not part_registry.list_parts().is_empty():
		return _failure("Choose a slot template before importing layers, or start a new empty project.")
	var template := FactoryScript.get_slot_template(template_id)
	if template.is_empty(): return _failure("Choose a valid slot template.")
	var before := _capture_document_snapshot()
	var slots := {}
	var order: Array[String] = []
	for slot in FactoryScript.create_slots_for_template(template_id):
		slots[slot.slot_id] = slot.to_dict()
		order.append(slot.slot_id)
	var authoring: Dictionary = manifest.metadata.get("character_authoring", {}).duplicate(true)
	authoring["slots"] = slots
	authoring["slot_order"] = order
	manifest.metadata["character_authoring"] = authoring
	manifest.metadata["template_id"] = template_id
	_hydrate_registries()
	model.configure(part_registry, slot_registry, body_types)
	model.set_history_recorder(Callable(self, "_record_model_history"))
	_commit_document_edit(before, "Selected %s Slot Template" % str(template.get("name", template_id)))
	return {"success": true, "errors": [], "template_id": template_id}


func map_files_to_slots(paths: Array) -> Dictionary:
	var mapped: Array = []
	var unmatched: Array = []
	var aliases := {
		"body": ["body", "base", "torso", "root"], "legs": ["leg", "legs", "pants", "lower"],
		"outfit": ["outfit", "shirt", "top", "torso", "clothes"], "head": ["head", "facebase"],
		"face": ["face", "eyes", "eye", "mouth", "brow"], "hair": ["hair", "fringe", "bang"],
		"hands": ["hand", "hands", "arm", "arms"], "accessory": ["accessory", "prop", "hat", "item"],
	}
	for entry in paths:
		var path := str(entry)
		if not ImageImporterScript.is_supported_format(path):
			unmatched.append({"path": path, "reason": "Unsupported image format"})
			continue
		var stem := path.get_file().get_basename().to_lower().replace("-", "_").replace(" ", "_")
		var chosen := ""
		for slot in get_slots():
			var candidates: Array = [str(slot.slot_id)]
			candidates.append_array(aliases.get(str(slot.slot_id), []))
			for token in candidates:
				if stem == token or stem.begins_with(token + "_") or ("_" + token + "_") in ("_" + stem + "_"):
					chosen = str(slot.slot_id)
					break
			if not chosen.is_empty(): break
		if chosen.is_empty():
			unmatched.append({"path": path, "reason": "Filename did not match a slot"})
		else:
			mapped.append({"path": path, "slot_id": chosen, "display_name": path.get_file().get_basename().capitalize()})
	return {"mapped": mapped, "unmatched": unmatched}


func import_files_by_slot(paths: Array, explicit_slot_id: String = "") -> Dictionary:
	if is_read_only(): return _failure("Bundled samples are read-only. Use Save As before importing artwork.")
	var plan := map_files_to_slots(paths)
	var imported: Array = []
	var errors: Array = []
	for row in plan.mapped:
		var slot := explicit_slot_id if not explicit_slot_id.is_empty() else str((row as Dictionary).get("slot_id", ""))
		var result := import_part(str((row as Dictionary).get("path", "")), slot, str((row as Dictionary).get("display_name", "")))
		if result.get("success", false): imported.append(result)
		else: errors.append_array(result.get("errors", []))
	if not explicit_slot_id.is_empty():
		for row in plan.unmatched:
			var result := import_part(str((row as Dictionary).get("path", "")), explicit_slot_id)
			if result.get("success", false): imported.append(result)
			else: errors.append_array(result.get("errors", []))
	return {"success": not imported.is_empty() and errors.is_empty(), "imported": imported, "unmatched": plan.unmatched, "errors": errors}


func import_folder(folder_path: String) -> Dictionary:
	var files: Array = []
	_collect_image_files(folder_path, files)
	if files.is_empty(): return _failure("The folder contains no supported PNG, WebP, or JPEG artwork.")
	return import_files_by_slot(files)


func duplicate_layer(part_id: String) -> Dictionary:
	if model == null or is_read_only(): return _failure("Use an editable project before duplicating a layer.")
	var source = part_registry.get_part(part_id)
	if source == null or part_id not in model.assembly.get_equipped_part_ids(): return _failure("Choose an equipped layer to duplicate.")
	var before := _capture_document_snapshot()
	var duplicate_id: String = IDService.generate_id("prt")
	var duplicate = PartScript.new(duplicate_id, source.display_name + " Copy", source.slot_id)
	duplicate.asset_id = source.asset_id
	duplicate.supported_body_type_ids = source.supported_body_type_ids.duplicate()
	duplicate.tags = source.tags.duplicate()
	duplicate.required_tags = source.required_tags.duplicate()
	duplicate.excluded_tags = source.excluded_tags.duplicate()
	duplicate.conflict_part_ids = source.conflict_part_ids.duplicate()
	duplicate.palette_channels = source.palette_channels.duplicate(true)
	duplicate.attachment_map = source.attachment_map.duplicate(true)
	duplicate.metadata = source.metadata.duplicate(true)
	duplicate.metadata["duplicate_of"] = part_id
	if not part_registry.register_part(duplicate): return _failure("The layer could not be duplicated.")
	var slot = slot_registry.get_slot(source.slot_id)
	if slot != null: slot.allow_multiple = true
	var selected: Array = model.assembly.equipped_by_slot.get(source.slot_id, []).duplicate()
	selected.append(duplicate_id)
	model.assembly.equipped_by_slot[source.slot_id] = selected
	var state: Dictionary = model.get_layer_state(part_id)
	var position: Array = state.get("position", [0.0, 0.0])
	state["position"] = [float(position[0]) + 8.0, float(position[1]) + 8.0]
	model.call("_set_layer_state", duplicate_id, state)
	_commit_document_edit(before, "Duplicated %s Layer" % source.display_name)
	return {"success": true, "errors": [], "part_id": duplicate_id}


func replace_layer_art(part_id: String, source_path: String) -> Dictionary:
	if model == null or is_read_only(): return _failure("Use an editable project before replacing a layer.")
	var part = part_registry.get_part(part_id)
	if part == null: return _failure("Choose a layer to replace.")
	var inspection := ImageImporterScript.inspect_image(source_path)
	if not inspection.get("valid", false): return _failure(str(inspection.get("error", "Image import failed.")))
	var before := _capture_document_snapshot()
	var copied_path := _copy_into_project(source_path, IDService.generate_id("replace"))
	if copied_path.is_empty(): return _failure("The replacement artwork could not be copied into the project.")
	var new_asset: Dictionary = ImageImporterScript.import_image(copied_path, asset_registry)
	if new_asset.is_empty() or not new_asset.has("asset_id"): return _failure("The replacement artwork could not be registered.")
	var old_asset_id: String = part.asset_id
	part.asset_id = str(new_asset.get("asset_id", ""))
	asset_registry.update_asset(part.asset_id, {"tags": ["character_part", part.slot_id], "metadata": {"character_part_id": part_id, "slot_id": part.slot_id}})
	if not _is_asset_referenced(old_asset_id): asset_registry.unregister_asset(old_asset_id)
	_commit_document_edit(before, "Replaced %s Layer Artwork" % part.display_name)
	return {"success": true, "errors": [], "asset_id": part.asset_id, "path": copied_path}


func delete_layer(part_id: String) -> Dictionary:
	if model == null or is_read_only(): return _failure("Use an editable project before deleting a layer.")
	var part = part_registry.get_part(part_id)
	if part == null: return _failure("Choose a layer to delete.")
	var before := _capture_document_snapshot()
	model.assembly.unequip_part(part_id)
	part_registry.unregister_part(part_id)
	if not _is_asset_referenced(part.asset_id): asset_registry.unregister_asset(part.asset_id)
	var states: Dictionary = model.assembly.metadata.get("layer_states", {}).duplicate(true)
	states.erase(part_id)
	model.assembly.metadata["layer_states"] = states
	var order: Array = model.assembly.metadata.get("layer_order", []).duplicate()
	order.erase(part_id)
	model.assembly.metadata["layer_order"] = order
	if str(model.assembly.metadata.get("solo_part_id", "")) == part_id: model.assembly.metadata["solo_part_id"] = ""
	_commit_document_edit(before, "Deleted %s Layer" % part.display_name)
	return {"success": true, "errors": []}


func repair_missing_artwork(search_folder: String) -> Dictionary:
	if is_read_only(): return _failure("Bundled samples are read-only. Save a copy before repairing artwork.")
	if search_folder.strip_edges().is_empty(): return _failure("Choose a folder to search for missing artwork.")
	var candidates: Array = []
	_collect_image_files(search_folder, candidates)
	if candidates.is_empty(): return _failure("No supported artwork was found in the repair folder.")
	var before := _capture_document_snapshot()
	var repaired := 0
	for asset in MissingFileRepairScript.find_missing_assets(asset_registry):
		var missing_path := str((asset as Dictionary).get("path", ""))
		var filename := missing_path.get_file().to_lower()
		for candidate in candidates:
			if str(candidate).get_file().to_lower() == filename and MissingFileRepairScript.relocate_asset(asset_registry, str((asset as Dictionary).get("asset_id", "")), str(candidate)):
				repaired += 1
				break
	if repaired == 0: return _failure("No missing artwork matched files in the selected folder.")
	_commit_document_edit(before, "Repaired %d Missing Artwork File%s" % [repaired, "s" if repaired != 1 else ""])
	return {"success": true, "errors": [], "repaired": repaired}


func get_asset_health_report() -> Dictionary:
	var referenced: Array = []
	for part in part_registry.list_parts(): referenced.append(part.asset_id)
	return AssetReportsScript.generate_report(asset_registry, referenced)


func save_project() -> Dictionary:
	if model == null: return _failure("Open a character project before saving.")
	if project_path.begins_with("res://"): return _failure("Bundled projects are read-only. Use Save As to create an editable copy.")
	var validation: Dictionary = model.assembly.validate()
	if not validation.get("success", false): return validation
	var missing := _missing_layer_paths()
	if not missing.is_empty(): return _failure("Missing imported image: " + str(missing[0]))
	_sync_manifest()
	if not SerializationService.save_project(manifest, project_path): return _failure("The project could not be saved.")
	project_saved.emit(project_path)
	return {"success": true, "errors": []}

func save_project_as(target_path: String) -> Dictionary:
	var target := target_path.strip_edges()
	if model == null or target.is_empty(): return _failure("Choose a valid path for the project copy.")
	if target.begins_with("res://"): return _failure("Choose a writable location outside the bundled application files.")
	if ProjectSettings.globalize_path(target) == ProjectSettings.globalize_path(project_path):
		var same_path_report := save_project()
		if same_path_report.get("success", false): same_path_report["path"] = project_path
		return same_path_report
	var validation: Dictionary = model.assembly.validate()
	if not validation.get("success", false): return validation
	var missing := _missing_layer_paths()
	if not missing.is_empty(): return _failure("Missing imported image: " + str(missing[0]))
	_sync_manifest()
	var next_manifest := manifest.duplicate(true)
	var copy_report := _copy_assets_for_project(next_manifest, target)
	if not copy_report.get("success", false): return copy_report
	if not SerializationService.save_project(next_manifest, target): return _failure("The project copy could not be saved.")
	project_path = target
	manifest = next_manifest
	asset_registry.from_dict({"assets": manifest.objects.assets})
	project_saved.emit(project_path)
	return {"success": true, "errors": [], "path": project_path}

func autosave_project() -> Dictionary:
	if model == null: return _failure("Open a character project before autosaving.")
	var validation: Dictionary = model.assembly.validate()
	if not validation.get("success", false): return validation
	_sync_manifest()
	var autosave_path := _autosave_path()
	if not SerializationService.autosave(manifest, autosave_path): return _failure("The autosave snapshot could not be written.")
	var bytes_written := FileAccess.get_file_as_bytes(autosave_path).size()
	RecoveryJournalScript.record_event("autosave", autosave_path, SerializationService.compute_hash(manifest), bytes_written)
	last_autosave_unix = Time.get_unix_time_from_system()
	return {"success": true, "errors": [], "path": autosave_path}

func get_preview_layers() -> Array:
	var layers: Array = []
	if model == null: return layers
	for part_id in model.get_layer_ids_in_order():
		var part = part_registry.get_part(str(part_id))
		if part == null: continue
		var asset: Dictionary = asset_registry.get_asset(part.asset_id)
		var path := str(asset.get("path", ""))
		layers.append({
			"part_id": part.part_id, "name": part.display_name, "slot_id": part.slot_id, "path": path,
			"state": model.get_layer_state(part.part_id), "visible": model.is_layer_effectively_visible(part.part_id),
			"missing": path.is_empty() or not FileAccess.file_exists(path),
		})
	return layers


func get_layer_entries() -> Array:
	var entries: Array = []
	for layer in get_preview_layers():
		var entry: Dictionary = (layer as Dictionary).duplicate(true)
		entry["asset"] = get_part_asset(str(entry.get("part_id", "")))
		entries.append(entry)
	return entries


func get_slots() -> Array:
	var result: Array = []
	for slot_id in _slot_order:
		var slot = slot_registry.get_slot(slot_id)
		if slot != null: result.append(slot)
	return result


func get_part_asset(part_id: String) -> Dictionary:
	var part = part_registry.get_part(part_id)
	return asset_registry.get_asset(part.asset_id) if part != null else {}


func _ensure_authoring_data() -> void:
	if not manifest.has("objects"): manifest["objects"] = {}
	for category in ["characters", "body_types", "assets"]:
		if not manifest.objects.has(category): manifest.objects[category] = {}
	if not manifest.has("metadata"): manifest["metadata"] = {}
	var authoring: Dictionary = manifest.metadata.get("character_authoring", {})
	if not authoring.has("slots") or (authoring.slots as Dictionary).is_empty():
		var slots := {}
		var order: Array[String] = []
		for slot in FactoryScript.create_default_slots():
			slots[slot.slot_id] = slot.to_dict()
			order.append(slot.slot_id)
		authoring["slots"] = slots
		authoring["slot_order"] = order
	if not authoring.has("parts"): authoring["parts"] = {}
	if not authoring.has("canvas"):
		authoring["canvas"] = FactoryScript.get_default_canvas_settings()
	if not authoring.has("slot_order") or (authoring.get("slot_order", []) as Array).is_empty():
		var recovered_order: Array = (authoring.get("slots", {}) as Dictionary).keys()
		recovered_order.sort()
		authoring["slot_order"] = recovered_order
	if (manifest.objects.body_types as Dictionary).is_empty():
		var body = FactoryScript.create_default_body_type()
		manifest.objects.body_types[body.body_type_id] = body.to_dict()
	if not authoring.has("active_character_id"):
		var character_ids: Array = manifest.objects.characters.keys()
		character_ids.sort()
		authoring["active_character_id"] = str(character_ids[0]) if not character_ids.is_empty() else FactoryScript.DEFAULT_CHARACTER_ID
	manifest.metadata["character_authoring"] = authoring


func _hydrate_registries() -> void:
	part_registry = PartRegistryScript.new()
	slot_registry = SlotRegistryScript.new()
	body_types.clear()
	var authoring: Dictionary = manifest.metadata.character_authoring
	_slot_order.clear()
	for slot_id in authoring.get("slot_order", []):
		var data: Dictionary = authoring.slots.get(slot_id, {})
		var slot = SlotScript.new().from_dict(data)
		if slot_registry.register_slot(slot): _slot_order.append(slot.slot_id)
	for part_data in (authoring.parts as Dictionary).values():
		part_registry.register_part(PartScript.new().from_dict(part_data))
	for body_data in (manifest.objects.body_types as Dictionary).values():
		var body = BodyScript.new().from_dict(body_data)
		if body.validate().is_empty(): body_types.append(body)
	asset_registry.from_dict({"assets": manifest.objects.assets})


func _hydrate_character() -> Dictionary:
	if body_types.is_empty(): return _failure("The project has no valid character body type.")
	active_character_id = str(manifest.metadata.character_authoring.active_character_id)
	model = ModelScript.new()
	add_child(model)
	model.configure(part_registry, slot_registry, body_types)
	var character_data: Dictionary = manifest.objects.characters.get(active_character_id, {})
	if character_data.has("assembly"):
		if model.from_dict(character_data): return {"success": true, "errors": []}
		return _failure("The saved character assembly is invalid.")
	if character_data.has("character_id"):
		model.apply_snapshot({"assembly": character_data})
		return model.assembly.validate()
	var body_id := str(character_data.get("body_type", manifest.settings.get("default_body_type", "")))
	if not _has_body_type(body_id): body_id = body_types[0].body_type_id
	var display_name := str(character_data.get("display_name", manifest.get("project_name", "Character")))
	return model.create_character(active_character_id, display_name, body_id)


func _sync_manifest() -> void:
	if model == null: return
	var authoring: Dictionary = manifest.metadata.character_authoring
	var slots := {}
	for slot in get_slots(): slots[slot.slot_id] = slot.to_dict()
	var parts := {}
	for part in part_registry.list_parts(): parts[part.part_id] = part.to_dict()
	authoring["slots"] = slots
	authoring["slot_order"] = _slot_order.duplicate()
	authoring["parts"] = parts
	authoring["active_character_id"] = active_character_id
	manifest.metadata["character_authoring"] = authoring
	manifest.objects.assets = asset_registry.to_dict().assets
	manifest.objects.characters[active_character_id] = model.to_dict()
	manifest["modified_at"] = Time.get_unix_time_from_system()


func _copy_into_project(source_path: String, part_id: String) -> String:
	var asset_dir := _asset_root_for_project(project_path).path_join("character_parts")
	var absolute_dir := ProjectSettings.globalize_path(asset_dir)
	if DirAccess.make_dir_recursive_absolute(absolute_dir) != OK and not DirAccess.dir_exists_absolute(absolute_dir): return ""
	var target := asset_dir.path_join(part_id + "_" + source_path.get_file().validate_filename())
	if DirAccess.copy_absolute(ProjectSettings.globalize_path(source_path), ProjectSettings.globalize_path(target)) != OK: return ""
	return target

func _copy_assets_for_project(next_manifest: Dictionary, target_path: String) -> Dictionary:
	var assets: Dictionary = next_manifest.objects.assets
	for asset_id in assets:
		var asset: Dictionary = (assets[asset_id] as Dictionary).duplicate(true)
		var source := str(asset.get("path", ""))
		if source.is_empty() or not FileAccess.file_exists(source): return _failure("Missing project asset: " + source)
		var folder := source.get_base_dir().get_file().validate_filename()
		if folder.is_empty(): folder = "assets"
		var target_dir := _asset_root_for_project(target_path).path_join(folder)
		var absolute_dir := ProjectSettings.globalize_path(target_dir)
		if DirAccess.make_dir_recursive_absolute(absolute_dir) != OK and not DirAccess.dir_exists_absolute(absolute_dir):
			return _failure("Could not create the project-copy asset folder.")
		var target := target_dir.path_join(str(asset_id) + "_" + source.get_file().validate_filename())
		if ProjectSettings.globalize_path(source) != ProjectSettings.globalize_path(target):
			if DirAccess.copy_absolute(ProjectSettings.globalize_path(source), ProjectSettings.globalize_path(target)) != OK:
				return _failure("Could not copy project asset: " + source)
		asset["path"] = target
		assets[asset_id] = asset
	next_manifest.objects.assets = assets
	return {"success": true, "errors": []}

func _asset_root_for_project(path: String) -> String:
	var project_base := path.get_base_dir()
	if path.begins_with("res://"): project_base = "user://project_assets/" + path.get_file().get_basename()
	return project_base.path_join(path.get_file().get_basename() + "_assets")

func _autosave_path() -> String:
	if project_path.begins_with("res://"):
		return "user://autosaves/" + project_path.get_file().get_basename() + ".autosave.json"
	return project_path.get_basename() + ".autosave.json"


func _missing_layer_paths() -> Array[String]:
	var missing: Array[String] = []
	for layer in get_preview_layers():
		var path := str(layer.path)
		if path.is_empty() or not FileAccess.file_exists(path): missing.append(path)
	return missing


func _capture_document_snapshot() -> Dictionary:
	_sync_manifest()
	return manifest.duplicate(true)


func _record_model_history(before_model: Dictionary, _after_model: Dictionary, description: String) -> bool:
	if _restoring_document: return false
	var before_document := manifest.duplicate(true)
	if not before_document.has("objects"): before_document["objects"] = {}
	if not before_document.objects.has("characters"): before_document.objects["characters"] = {}
	before_document.objects.characters[active_character_id] = before_model.duplicate(true)
	_sync_manifest()
	var after_document := manifest.duplicate(true)
	return _record_document_snapshots(before_document, after_document, description)


func _commit_document_edit(before_document: Dictionary, description: String) -> bool:
	_sync_manifest()
	return _record_document_snapshots(before_document, manifest.duplicate(true), description)


func _record_document_snapshots(before_document: Dictionary, after_document: Dictionary, description: String) -> bool:
	if before_document == after_document: return false
	if CommandService != null:
		CommandService.execute(
			{"target": self, "method": "_apply_document_snapshot", "args": [after_document, description]},
			{"target": self, "method": "_apply_document_snapshot", "args": [before_document, "Undid " + description]},
			description
		)
		return true
	_apply_document_snapshot(after_document, description)
	return true


func _apply_document_snapshot(snapshot: Dictionary, description: String = "") -> void:
	if snapshot.is_empty(): return
	_restoring_document = true
	manifest = snapshot.duplicate(true)
	_ensure_authoring_data()
	_hydrate_registries()
	active_character_id = str(manifest.metadata.character_authoring.get("active_character_id", active_character_id))
	var character_data: Dictionary = manifest.objects.characters.get(active_character_id, {})
	if model == null:
		_hydrate_character()
		if model != null and not model.changed.is_connected(_on_model_changed): model.changed.connect(_on_model_changed)
	elif character_data.has("assembly"):
		model.configure(part_registry, slot_registry, body_types)
		model.from_dict(character_data)
	else:
		model.configure(part_registry, slot_registry, body_types)
	model.set_history_recorder(Callable(self, "_record_model_history"))
	_restoring_document = false
	if CommandService == null and AppState != null: AppState.mark_dirty()
	session_changed.emit(description if not description.is_empty() else "Updated project")


func _collect_image_files(folder_path: String, output: Array) -> void:
	var folder := folder_path.strip_edges()
	var dir := DirAccess.open(folder)
	if dir == null: return
	dir.list_dir_begin()
	var entry := dir.get_next()
	while not entry.is_empty():
		if entry != "." and entry != "..":
			var full_path := folder.path_join(entry)
			if dir.current_is_dir():
				_collect_image_files(full_path, output)
			elif ImageImporterScript.is_supported_format(full_path):
				output.append(full_path)
		entry = dir.get_next()
	dir.list_dir_end()
	output.sort()


func _is_asset_referenced(asset_id: String) -> bool:
	if asset_id.is_empty(): return false
	for part in part_registry.list_parts():
		if part.asset_id == asset_id: return true
	return false


func _duplicate_asset_ids(checksum: String, exclude_asset_id: String = "") -> Array[String]:
	var duplicates: Array[String] = []
	if checksum.is_empty(): return duplicates
	for asset in asset_registry.list_assets():
		if str((asset as Dictionary).get("asset_id", "")) != exclude_asset_id and str((asset as Dictionary).get("checksum", "")) == checksum:
			duplicates.append(str((asset as Dictionary).get("asset_id", "")))
	return duplicates


func _has_body_type(body_id: String) -> bool:
	for body in body_types:
		if body.body_type_id == body_id: return true
	return false


func _on_model_changed(description: String) -> void:
	if _restoring_document: return
	_sync_manifest()
	if AppState != null: AppState.mark_dirty()
	session_changed.emit(description)


func _failure(message: String) -> Dictionary:
	return {"success": false, "errors": [message], "repair_actions": []}
