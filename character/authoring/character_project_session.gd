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
const AssetImportPreflightScript = preload("res://core/assets/asset_import_preflight.gd")
const RigSchemaScript = preload("res://rigging/bones/rig_schema.gd")
const BoneSchemaScript = preload("res://rigging/bones/bone_schema.gd")
const BoneManagerScript = preload("res://rigging/bones/bone_manager.gd")
const AnimationClipScript = preload("res://animation/clips/clip_schema.gd")
const TrackDefinitionScript = preload("res://animation/tracks/track_schema.gd")
const SnapshotServiceScript = preload("res://core/documents/project_snapshot_service.gd")
const ReadinessValidatorScript = preload("res://quality/readiness/project_readiness_validator.gd")
const ProjectScaleAdvisorScript = preload("res://quality/performance/project_scale_advisor.gd")
const ProductionDataScript = preload("res://production/production_project_data.gd")

signal session_changed(description: String)
signal project_saved(path: String)
signal snapshots_changed()
signal appearance_sets_changed()

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
var _rigs: Dictionary = {}
var last_autosave_unix: int = 0
var _restoring_document := false
var _snapshot_service = SnapshotServiceScript.new()
var _readiness_validator = ReadinessValidatorScript.new()
var _scale_advisor = ProjectScaleAdvisorScript.new()

func _init() -> void:
	# These services are part of the session's lifetime even when a session is
	# used off-tree (for CLI, tests, or background workflows). Owning them from
	# construction guarantees that freeing the session also frees its services.
	add_child(asset_registry)
	add_child(thumbnail_cache)


func open_project(path: String) -> Dictionary:
	var loaded: Dictionary = SerializationService.load_project(path)
	if loaded.is_empty(): return _failure("The project file is invalid or could not be read.")
	project_path = path
	manifest = loaded.duplicate(true)
	_ensure_authoring_data()
	_hydrate_registries()
	_hydrate_rigs()
	var report := _hydrate_character()
	if not report.get("success", false): return report
	model.set_history_recorder(Callable(self, "_record_model_history"))
	model.changed.connect(_on_model_changed)
	return {"success": true, "errors": []}


func import_part(source_path: String, slot_id: String, display_name: String = "") -> Dictionary:
	if is_read_only(): return _failure("Bundled samples are read-only. Use Save As before importing artwork.")
	if model == null or not slot_registry.has_slot(slot_id):
		return _failure("Choose a valid layer slot before importing art.")
	var preflight: Dictionary = preflight_artwork_import([source_path], slot_id)
	if not bool(preflight.get("success", false)):
		return {"success": false, "errors": _issue_messages(preflight.get("errors", [])), "preflight": preflight, "repair_actions": []}
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
	var asset_metadata := {
		"character_part_id": part_id,
		"slot_id": slot_id,
		"provenance": AssetImportPreflightScript.provenance_from_inspection(source_path, inspection),
	}
	asset_registry.update_asset(part.asset_id, {
		"tags": ["character_part", slot_id],
		"metadata": asset_metadata,
	})
	var equip_report: Dictionary = model.equip_part(part_id)
	if not equip_report.get("success", false): return equip_report
	_sync_manifest()
	return {"success": true, "errors": [], "part_id": part_id, "asset_id": part.asset_id, "path": copied_path, "duplicate_asset_ids": duplicate_asset_ids, "preflight": preflight}


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


func get_production_suite_data() -> Dictionary:
	return ProductionDataScript.from_manifest(manifest)


func get_manifest_copy() -> Dictionary:
	_sync_manifest()
	return manifest.duplicate(true)


func set_production_suite_data(data: Dictionary, description: String = "Updated Production Suite Settings") -> Dictionary:
	if is_read_only(): return _failure("Bundled samples are read-only. Use Save As before changing production settings.")
	var normalized := ProductionDataScript.normalize(data)
	if normalized == get_production_suite_data(): return {"success": true, "changed": false, "errors": []}
	var before := _capture_document_snapshot()
	manifest = ProductionDataScript.apply_to_manifest(manifest, normalized)
	var changed := _commit_document_edit(before, description)
	return {"success": changed, "changed": changed, "errors": [] if changed else ["Production settings were unchanged."]}


func get_workflow_state() -> Dictionary:
	var authoring: Dictionary = manifest.get("metadata", {}).get("character_authoring", {})
	var workflow: Dictionary = authoring.get("workflow", {})
	return {"new_project": bool(workflow.get("new_project", false)), "completed": bool(workflow.get("completed", true)), "current_step": clampi(int(workflow.get("current_step", 0)), 0, 5), "deferred": bool(workflow.get("deferred", false))}


func set_workflow_state(updates: Dictionary, description: String = "Updated Guided Setup") -> bool:
	if is_read_only() or model == null: return false
	var current := get_workflow_state()
	var next := current.duplicate(true)
	for key in updates:
		if key in ["new_project", "completed", "deferred"]: next[key] = bool(updates[key])
		elif key == "current_step": next[key] = clampi(int(updates[key]), 0, 5)
	if next == current: return false
	var before := _capture_document_snapshot()
	var authoring: Dictionary = manifest.metadata.get("character_authoring", {}).duplicate(true)
	authoring["workflow"] = next
	manifest.metadata["character_authoring"] = authoring
	_commit_document_edit(before, description)
	return true


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
	var seen_paths: Dictionary = {}
	for row in plan.mapped:
		var source_path := str((row as Dictionary).get("path", ""))
		var normalized := source_path.replace("\\", "/").simplify_path().to_lower()
		if seen_paths.has(normalized): continue
		seen_paths[normalized] = true
		var slot := explicit_slot_id if not explicit_slot_id.is_empty() else str((row as Dictionary).get("slot_id", ""))
		var result := import_part(source_path, slot, str((row as Dictionary).get("display_name", "")))
		if result.get("success", false): imported.append(result)
		else: errors.append_array(result.get("errors", []))
	if not explicit_slot_id.is_empty():
		for row in plan.unmatched:
			var unmatched_path := str((row as Dictionary).get("path", ""))
			var unmatched_normalized := unmatched_path.replace("\\", "/").simplify_path().to_lower()
			if seen_paths.has(unmatched_normalized): continue
			seen_paths[unmatched_normalized] = true
			var result := import_part(unmatched_path, explicit_slot_id)
			if result.get("success", false): imported.append(result)
			else: errors.append_array(result.get("errors", []))
	return {"success": not imported.is_empty() and errors.is_empty(), "imported": imported, "unmatched": plan.unmatched, "errors": errors}


func import_folder(folder_path: String) -> Dictionary:
	var files: Array = []
	_collect_image_files(folder_path, files)
	if files.is_empty(): return _failure("The folder contains no supported PNG, WebP, or JPEG artwork.")
	return import_files_by_slot(files)


func import_audio_asset(source_path: String, display_name: String = "") -> Dictionary:
	if is_read_only(): return _failure("Bundled samples are read-only. Use Save As before importing audio.")
	var extension := source_path.get_extension().to_lower()
	if extension not in ["wav", "ogg", "mp3", "flac"] or not FileAccess.file_exists(source_path):
		return _failure("Choose an imported WAV, OGG, MP3, or FLAC audio file.")
	var before := _capture_document_snapshot()
	var copied_path := _copy_asset_into_project(source_path, IDService.generate_id("aud"), "audio")
	if copied_path.is_empty(): return _failure("The audio file could not be copied into the project assets folder.")
	var bytes := FileAccess.get_file_as_bytes(copied_path)
	var hash := HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	hash.update(bytes)
	var checksum := hash.finish().hex_encode()
	var audio_provenance := {"source_filename": source_path.get_file(), "source_checksum": checksum, "source_format": extension, "imported_at": Time.get_unix_time_from_system(), "author": "", "license": "", "source_reference": ""}
	var asset: Dictionary = asset_registry.register_asset(copied_path, AssetRegistryScript.CATEGORY_AUDIO, {"checksum": checksum, "metadata": {"source": "imported_audio", "provenance": audio_provenance}})
	if asset.is_empty(): return _failure("The audio file could not be registered.")
	if not display_name.strip_edges().is_empty(): asset_registry.update_asset(str(asset.get("asset_id", "")), {"name": display_name.strip_edges()})
	_commit_document_edit(before, "Imported Audio " + (display_name.strip_edges() if not display_name.strip_edges().is_empty() else source_path.get_file().get_basename()))
	return {"success": true, "errors": [], "asset_id": str(asset.get("asset_id", "")), "path": copied_path}


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
	var preflight: Dictionary = preflight_artwork_import([source_path], part.slot_id)
	if not bool(preflight.get("success", false)):
		return {"success": false, "errors": _issue_messages(preflight.get("errors", [])), "preflight": preflight, "repair_actions": []}
	var inspection := ImageImporterScript.inspect_image(source_path)
	if not inspection.get("valid", false): return _failure(str(inspection.get("error", "Image import failed.")))
	var before := _capture_document_snapshot()
	var copied_path := _copy_into_project(source_path, IDService.generate_id("replace"))
	if copied_path.is_empty(): return _failure("The replacement artwork could not be copied into the project.")
	var new_asset: Dictionary = ImageImporterScript.import_image(copied_path, asset_registry)
	if new_asset.is_empty() or not new_asset.has("asset_id"): return _failure("The replacement artwork could not be registered.")
	var old_asset_id: String = part.asset_id
	part.asset_id = str(new_asset.get("asset_id", ""))
	asset_registry.update_asset(part.asset_id, {"tags": ["character_part", part.slot_id], "metadata": {"character_part_id": part_id, "slot_id": part.slot_id, "provenance": AssetImportPreflightScript.provenance_from_inspection(source_path, inspection)}})
	if not _is_asset_referenced(old_asset_id): asset_registry.unregister_asset(old_asset_id)
	_commit_document_edit(before, "Replaced %s Layer Artwork" % part.display_name)
	return {"success": true, "errors": [], "asset_id": part.asset_id, "path": copied_path, "preflight": preflight}


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
	var plan: Dictionary = MissingFileRepairScript.plan_deterministic_repairs(asset_registry, candidates, [AssetRegistryScript.CATEGORY_SOURCE_ART])
	var before := _capture_document_snapshot()
	var repaired := 0
	for raw_repair in plan.get("repairs", []):
		var repair: Dictionary = raw_repair
		var asset_id := str(repair.get("asset_id", ""))
		var copied_path := _copy_asset_into_project(str(repair.get("candidate_path", "")), "repair_" + asset_id, "repaired_artwork")
		if not copied_path.is_empty() and MissingFileRepairScript.relocate_asset(asset_registry, asset_id, copied_path):
			repaired += 1
	if repaired == 0:
		var ambiguous: Array = plan.get("ambiguous", [])
		var unresolved: Array = plan.get("unresolved", [])
		var message := "%d missing artwork file%s have more than one filename match; choose a replacement manually." % [ambiguous.size(), "s" if ambiguous.size() != 1 else ""] if not ambiguous.is_empty() else "No unambiguous missing artwork could be repaired from the selected folder."
		if not unresolved.is_empty(): message += " %d file%s were not found." % [unresolved.size(), "s" if unresolved.size() != 1 else ""]
		return {"success": false, "errors": [message], "ambiguous": ambiguous, "unresolved": unresolved, "repair_actions": []}
	_commit_document_edit(before, "Repaired %d Missing Artwork File%s" % [repaired, "s" if repaired != 1 else ""])
	return {"success": true, "errors": [], "repaired": repaired, "ambiguous": plan.get("ambiguous", []), "unresolved": plan.get("unresolved", []), "planned": plan.get("repairs", [])}


func get_asset_health_report() -> Dictionary:
	var referenced: Array = []
	for part in part_registry.list_parts(): referenced.append(part.asset_id)
	var report: Dictionary = AssetReportsScript.generate_report(asset_registry, referenced)
	report["preflight"] = get_import_preflight_report()
	return report


## Preflight remains read-only so the file picker, drag-and-drop, and folder
## import paths can all show the same result before copying artwork.
func preflight_artwork_import(paths: Array, slot_id: String = "") -> Dictionary:
	var report: Dictionary = AssetImportPreflightScript.inspect_paths(paths, asset_registry, {"canvas": get_canvas_settings()})
	if not slot_id.is_empty() and not slot_registry.has_slot(slot_id):
		var issue := {"id": "invalid_slot", "severity": "error", "message": "Choose a valid layer slot before importing artwork.", "slot_id": slot_id}
		report.errors.append(issue)
		report["error_count"] = (report.get("errors", []) as Array).size()
		report["success"] = false
	return report


func get_import_preflight_report() -> Dictionary:
	return AssetImportPreflightScript.audit_registry(asset_registry, {"canvas": get_canvas_settings()})


func get_asset_provenance(asset_id: String) -> Dictionary:
	var asset: Dictionary = asset_registry.get_asset(asset_id)
	return (asset.get("metadata", {}) as Dictionary).get("provenance", {}) as Dictionary


func set_asset_provenance(asset_id: String, updates: Dictionary) -> bool:
	if is_read_only() or asset_id.is_empty(): return false
	var asset: Dictionary = asset_registry.get_asset(asset_id)
	if asset.is_empty(): return false
	var metadata: Dictionary = (asset.get("metadata", {}) as Dictionary).duplicate(true)
	var existing: Dictionary = metadata.get("provenance", {}) as Dictionary
	var next: Dictionary = AssetImportPreflightScript.merge_provenance(existing, updates)
	if next == existing: return false
	var before := _capture_document_snapshot()
	metadata["provenance"] = next
	asset_registry.update_asset(asset_id, {"metadata": metadata})
	_commit_document_edit(before, "Updated Asset Provenance")
	return true


func get_project_scale_report(options: Dictionary = {}) -> Dictionary:
	return _scale_advisor.analyze(self, options)


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


# === Named project snapshots =================================================

func create_project_snapshot(display_name: String, note: String = "") -> Dictionary:
	if is_read_only(): return _failure("Bundled samples are read-only. Use Save As before creating a snapshot.")
	if model == null: return _failure("Open a character project before creating a snapshot.")
	_sync_manifest()
	var report: Dictionary = _snapshot_service.create(project_path, manifest, display_name, note)
	if report.get("success", false):
		snapshots_changed.emit()
		session_changed.emit("Created snapshot " + str((report.get("snapshot", {}) as Dictionary).get("name", display_name)))
	return report


func list_project_snapshots() -> Array:
	return _snapshot_service.list(project_path)


func get_project_snapshot(snapshot_id: String) -> Dictionary:
	return _snapshot_service.get_snapshot(project_path, snapshot_id)


func restore_project_snapshot(snapshot_id: String) -> Dictionary:
	if is_read_only(): return _failure("Bundled samples are read-only. Use Save As before restoring a snapshot.")
	if model == null: return _failure("Open a character project before restoring a snapshot.")
	var before := _capture_document_snapshot()
	var snapshot := _snapshot_service.get_snapshot(project_path, snapshot_id)
	var report: Dictionary = _snapshot_service.restore(project_path, snapshot_id, before)
	if not report.get("success", false): return report
	var restored: Dictionary = report.get("manifest", {})
	if restored.is_empty(): return _failure("The restored snapshot did not include project data.")
	_record_document_snapshots(before, restored, "Restored Snapshot " + str(snapshot.get("name", snapshot_id)))
	snapshots_changed.emit()
	return report


func delete_project_snapshot(snapshot_id: String) -> Dictionary:
	var report: Dictionary = _snapshot_service.delete(project_path, snapshot_id)
	if report.get("success", false):
		snapshots_changed.emit()
		session_changed.emit("Deleted project snapshot")
	return report


func reveal_project_snapshot(snapshot_id: String = "") -> Dictionary:
	return _snapshot_service.reveal(project_path, snapshot_id)


# === Project readiness and deterministic repair =============================

func get_readiness_report(options: Dictionary = {}) -> Dictionary:
	return _readiness_validator.validate(self, options)


func auto_repair_all() -> Dictionary:
	return _readiness_validator.auto_repair_all(self)


# === Appearance Sets ========================================================

func get_appearance_sets() -> Array:
	return model.get_appearance_sets() if model != null else []


func create_appearance_set(display_name: String) -> Dictionary:
	if is_read_only(): return _failure("Bundled samples are read-only. Use Save As before saving an Appearance Set.")
	if model == null: return _failure("Open a character project before saving an Appearance Set.")
	var clean_name := display_name.strip_edges()
	if clean_name.is_empty(): clean_name = "Appearance Set"
	var before := _capture_document_snapshot()
	var appearance_id := IDService.generate_id("appearance")
	if not model.create_appearance_set(appearance_id, clean_name): return _failure("The Appearance Set could not be created.")
	_commit_document_edit(before, "Created Appearance Set " + clean_name)
	appearance_sets_changed.emit()
	return {"success": true, "errors": [], "appearance_id": appearance_id}


func rename_appearance_set(appearance_id: String, display_name: String) -> bool:
	if is_read_only() or model == null: return false
	var before := _capture_document_snapshot()
	if not model.rename_appearance_set(appearance_id, display_name): return false
	_commit_document_edit(before, "Renamed Appearance Set to " + display_name.strip_edges())
	appearance_sets_changed.emit()
	return true


func duplicate_appearance_set(appearance_id: String, display_name: String = "") -> Dictionary:
	if is_read_only() or model == null: return _failure("Use an editable project before duplicating an Appearance Set.")
	var source := _appearance_set(appearance_id)
	if source.is_empty(): return _failure("Choose an Appearance Set to duplicate.")
	var before := _capture_document_snapshot()
	var duplicate_id := IDService.generate_id("appearance")
	var name := display_name.strip_edges() if not display_name.strip_edges().is_empty() else str(source.get("name", appearance_id)) + " Copy"
	if not model.duplicate_appearance_set(appearance_id, duplicate_id, name): return _failure("The Appearance Set could not be duplicated.")
	_commit_document_edit(before, "Duplicated Appearance Set " + name)
	appearance_sets_changed.emit()
	return {"success": true, "errors": [], "appearance_id": duplicate_id}


func delete_appearance_set(appearance_id: String) -> bool:
	if is_read_only() or model == null: return false
	var source := _appearance_set(appearance_id)
	if source.is_empty(): return false
	var before := _capture_document_snapshot()
	if not model.delete_appearance_set(appearance_id): return false
	_commit_document_edit(before, "Deleted Appearance Set " + str(source.get("name", appearance_id)))
	appearance_sets_changed.emit()
	return true


func apply_appearance_set(appearance_id: String) -> Dictionary:
	if is_read_only() or model == null: return _failure("Use an editable project before applying an Appearance Set.")
	var report: Dictionary = model.apply_appearance_set(appearance_id)
	if report.get("success", false): appearance_sets_changed.emit()
	return report


func get_appearance_preview_layers(appearance_id: String) -> Array:
	if model == null: return []
	var appearance := _appearance_set(appearance_id)
	if appearance.is_empty(): return get_preview_layers()
	return _preview_layers_for_assembly((appearance.get("equipped_by_slot", {}) as Dictionary).duplicate(true))


func generate_appearance_sets(count: int, prefix: String = "Variation", confirmed: bool = false) -> Dictionary:
	if is_read_only(): return _failure("Bundled samples are read-only. Use Save As before generating Appearance Sets.")
	if model == null: return _failure("Open a character project before generating Appearance Sets.")
	var requested: int = max(1, count)
	if requested > 64 and not confirmed:
		return {"success": false, "requires_confirmation": true, "max_without_confirmation": 64, "requested": requested, "errors": ["Generate more than 64 Appearance Sets only after confirming the larger request."]}
	if not confirmed:
		return {"success": false, "requires_confirmation": true, "requested": requested, "errors": ["Confirm generation to save deterministic combinations of the artwork already imported into this project."]}
	var candidates := _deterministic_appearance_candidates(requested)
	if candidates.is_empty(): return _failure("There are not enough compatible imported parts to build an Appearance Set.")
	var before := _capture_document_snapshot()
	var created: Array = []
	var index := 1
	for data in candidates:
		var appearance_id := IDService.generate_id("appearance")
		var name := "%s %02d" % [prefix.strip_edges() if not prefix.strip_edges().is_empty() else "Variation", index]
		var source: Dictionary = data
		source["kind"] = "generated_imported_parts"
		if model.create_appearance_set(appearance_id, name, source): created.append(appearance_id)
		index += 1
	if created.is_empty(): return _failure("No Appearance Sets could be saved.")
	_commit_document_edit(before, "Generated %d Imported Appearance Set%s" % [created.size(), "s" if created.size() != 1 else ""])
	appearance_sets_changed.emit()
	return {"success": true, "errors": [], "appearance_ids": created, "requested": requested, "generated": created.size(), "import_only": true}

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


func _preview_layers_for_assembly(equipped_by_slot: Dictionary) -> Array:
	if model == null: return []
	var ids: Array[String] = []
	for part_id in model.get_layer_ids_in_order():
		if _equipped_map_contains(equipped_by_slot, str(part_id)): ids.append(str(part_id))
	for slot_id in equipped_by_slot:
		for raw_part_id in (equipped_by_slot[slot_id] as Array):
			var part_id := str(raw_part_id)
			if part_id not in ids: ids.append(part_id)
	var layers: Array = []
	for part_id in ids:
		var part = part_registry.get_part(part_id)
		if part == null: continue
		var asset: Dictionary = asset_registry.get_asset(part.asset_id)
		var path := str(asset.get("path", ""))
		layers.append({"part_id": part.part_id, "name": part.display_name, "slot_id": part.slot_id, "path": path, "state": model.get_layer_state(part.part_id), "visible": model.is_layer_effectively_visible(part.part_id), "missing": path.is_empty() or not FileAccess.file_exists(path)})
	return layers


func _equipped_map_contains(equipped_by_slot: Dictionary, part_id: String) -> bool:
	for slot_id in equipped_by_slot:
		if part_id in (equipped_by_slot[slot_id] as Array): return true
	return false


func _appearance_set(appearance_id: String) -> Dictionary:
	for raw in get_appearance_sets():
		var appearance: Dictionary = raw
		if str(appearance.get("appearance_id", "")) == appearance_id: return appearance
	return {}


func _deterministic_appearance_candidates(requested: int) -> Array:
	var varying_slots: Array = []
	for slot in get_slots():
		var choices: Array = part_registry.list_parts({"slot_id": str(slot.slot_id), "body_type_id": model.assembly.body_type_id})
		if choices.is_empty(): continue
		varying_slots.append({"slot_id": str(slot.slot_id), "choices": choices})
	if varying_slots.is_empty(): return []
	var total := 1
	for entry in varying_slots:
		total *= max(1, (entry as Dictionary).get("choices", []).size())
	var candidate_count: int = min(requested, total)
	var result: Array = []
	for combination in range(candidate_count):
		var cursor := combination
		var equipped: Dictionary = {}
		for entry in varying_slots:
			var info: Dictionary = entry
			var choices: Array = info.get("choices", [])
			var selected_index := cursor % choices.size()
			cursor = cursor / choices.size()
			var selected = choices[selected_index]
			equipped[str(info.get("slot_id", ""))] = [selected.part_id]
		result.append({"equipped_by_slot": equipped, "palette_values": model.assembly.palette_values.duplicate(true), "attachment_maps": model.assembly.attachment_maps.duplicate(true)})
	return result


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


# === Rig authoring ===========================================================

func get_rigs() -> Array:
	var rigs: Array = []
	var rig_ids: Array = _rigs.keys()
	rig_ids.sort()
	for rig_id in rig_ids:
		rigs.append((_rigs[rig_id] as Dictionary).duplicate(true))
	return rigs


func get_active_rig_id() -> String:
	return str(manifest.get("metadata", {}).get("character_authoring", {}).get("active_rig_id", ""))


func get_active_rig() -> Dictionary:
	var rig_id := get_active_rig_id()
	if rig_id.is_empty() or not _rigs.has(rig_id): return {}
	return _rigs[rig_id] as Dictionary


func get_rig(rig_id: String) -> Dictionary:
	return _rigs.get(rig_id, {}) as Dictionary


func set_active_rig_id(rig_id: String) -> bool:
	if not rig_id.is_empty() and not _rigs.has(rig_id): return false
	var authoring: Dictionary = manifest.get("metadata", {}).get("character_authoring", {}).duplicate(true)
	if str(authoring.get("active_rig_id", "")) == rig_id: return false
	authoring["active_rig_id"] = rig_id
	manifest.metadata["character_authoring"] = authoring
	session_changed.emit("Selected " + (str((_rigs[rig_id] as Dictionary).get("name", rig_id)) if not rig_id.is_empty() else "no rig"))
	return true


func create_rig(display_name: String = "Character Rig") -> Dictionary:
	if is_read_only(): return _failure("Bundled samples are read-only. Use Save As before creating a rig.")
	var name := display_name.strip_edges()
	if name.is_empty(): name = "Character Rig"
	var before := _capture_document_snapshot()
	var rig_id: String = IDService.generate_id("rig")
	_rigs[rig_id] = RigSchemaScript.create_empty_rig(rig_id, name)
	var authoring: Dictionary = manifest.metadata.character_authoring.duplicate(true)
	authoring["active_rig_id"] = rig_id
	manifest.metadata["character_authoring"] = authoring
	_commit_document_edit(before, "Created %s Rig" % name)
	return {"success": true, "errors": [], "rig_id": rig_id}


func rename_rig(rig_id: String, display_name: String) -> bool:
	if is_read_only() or not _rigs.has(rig_id): return false
	var name := display_name.strip_edges()
	if name.is_empty(): return false
	var rig: Dictionary = _rigs[rig_id]
	if str(rig.get("name", "")) == name: return false
	var before := _capture_document_snapshot()
	rig["name"] = name
	_rigs[rig_id] = rig
	_commit_document_edit(before, "Renamed Rig to %s" % name)
	return true


func delete_rig(rig_id: String) -> bool:
	if is_read_only() or not _rigs.has(rig_id): return false
	var name := str((_rigs[rig_id] as Dictionary).get("name", rig_id))
	var before := _capture_document_snapshot()
	_rigs.erase(rig_id)
	var authoring: Dictionary = manifest.metadata.character_authoring.duplicate(true)
	if str(authoring.get("active_rig_id", "")) == rig_id:
		var remaining: Array = _rigs.keys()
		remaining.sort()
		authoring["active_rig_id"] = str(remaining[0]) if not remaining.is_empty() else ""
	manifest.metadata["character_authoring"] = authoring
	_commit_document_edit(before, "Deleted %s Rig" % name)
	return true


func create_rig_bone(rig_id: String, display_name: String = "Bone", parent_id: String = "", length: float = 50.0) -> Dictionary:
	if is_read_only(): return _failure("Bundled samples are read-only. Use Save As before editing the rig.")
	if not _rigs.has(rig_id): return _failure("Choose a rig before adding a bone.")
	var rig: Dictionary = _rigs[rig_id]
	var bones: Dictionary = rig.get("bones", {})
	if not parent_id.is_empty() and not bones.has(parent_id): return _failure("The parent bone no longer exists.")
	var name := display_name.strip_edges()
	if name.is_empty(): name = "Bone"
	var before := _capture_document_snapshot()
	var bone_id: String = IDService.generate_id("bone")
	var bone: Dictionary = BoneSchemaScript.create_default_bone(bone_id, name, parent_id)
	bone["length"] = maxf(1.0, length)
	if not parent_id.is_empty():
		var parent: Dictionary = bones[parent_id]
		var children: Array = parent.get("children", []).duplicate()
		children.append(bone_id)
		parent["children"] = children
		bones[parent_id] = parent
	bones[bone_id] = bone
	rig["bones"] = bones
	if str(rig.get("root_bone_id", "")).is_empty(): rig["root_bone_id"] = bone_id
	_rigs[rig_id] = rig
	_commit_document_edit(before, "Added %s Bone" % name)
	return {"success": true, "errors": [], "bone_id": bone_id}


func delete_rig_bone(rig_id: String, bone_id: String) -> bool:
	if is_read_only() or not _rigs.has(rig_id): return false
	var rig: Dictionary = _rigs[rig_id]
	var bones: Dictionary = rig.get("bones", {})
	if not bones.has(bone_id): return false
	var name := str((bones[bone_id] as Dictionary).get("name", bone_id))
	var before := _capture_document_snapshot()
	_remove_bone_from_rig(rig, bone_id)
	_rigs[rig_id] = rig
	_commit_document_edit(before, "Deleted %s Bone" % name)
	return true


func reparent_rig_bone(rig_id: String, bone_id: String, new_parent_id: String) -> bool:
	if is_read_only() or not _rigs.has(rig_id): return false
	var rig: Dictionary = _rigs[rig_id]
	var bones: Dictionary = rig.get("bones", {})
	if not bones.has(bone_id) or (not new_parent_id.is_empty() and not bones.has(new_parent_id)) or bone_id == new_parent_id:
		return false
	var ancestor := new_parent_id
	var visited: Dictionary = {}
	while not ancestor.is_empty():
		if ancestor == bone_id: return false
		if visited.has(ancestor): return false
		visited[ancestor] = true
		ancestor = str((bones.get(ancestor, {}) as Dictionary).get("parent_id", ""))
	var bone: Dictionary = bones[bone_id]
	if str(bone.get("parent_id", "")) == new_parent_id: return false
	var before := _capture_document_snapshot()
	var old_parent_id := str(bone.get("parent_id", ""))
	if not old_parent_id.is_empty() and bones.has(old_parent_id):
		var old_parent: Dictionary = bones[old_parent_id]
		var old_children: Array = old_parent.get("children", []).duplicate()
		old_children.erase(bone_id)
		old_parent["children"] = old_children
		bones[old_parent_id] = old_parent
	bone["parent_id"] = new_parent_id
	bones[bone_id] = bone
	if not new_parent_id.is_empty():
		var new_parent: Dictionary = bones[new_parent_id]
		var children: Array = new_parent.get("children", []).duplicate()
		if not children.has(bone_id): children.append(bone_id)
		new_parent["children"] = children
		bones[new_parent_id] = new_parent
	if str(rig.get("root_bone_id", "")) == bone_id and not new_parent_id.is_empty():
		rig["root_bone_id"] = _find_first_root_bone_id(bones)
	elif str(rig.get("root_bone_id", "")).is_empty() and new_parent_id.is_empty():
		rig["root_bone_id"] = bone_id
	rig["bones"] = bones
	_rigs[rig_id] = rig
	_commit_document_edit(before, "Reparented %s Bone" % str(bone.get("name", bone_id)))
	return true


func set_rig_bone_name(rig_id: String, bone_id: String, display_name: String) -> bool:
	var name := display_name.strip_edges()
	if name.is_empty(): return false
	return _set_rig_bone_value(rig_id, bone_id, "name", name, "Renamed Bone to " + name)


func set_rig_bone_transform(rig_id: String, bone_id: String, position: Vector2, rotation_degrees: float, scale: Vector2, description: String = "") -> bool:
	if is_read_only() or not _rigs.has(rig_id): return false
	var rig: Dictionary = _rigs[rig_id]
	var bones: Dictionary = rig.get("bones", {})
	if not bones.has(bone_id): return false
	var bone: Dictionary = bones[bone_id]
	var next_position := position
	var next_rotation := deg_to_rad(rotation_degrees)
	var next_scale := Vector2(maxf(0.01, scale.x), maxf(0.01, scale.y))
	if bone.get("local_position", Vector2.ZERO) == next_position and is_equal_approx(float(bone.get("local_rotation", 0.0)), next_rotation) and bone.get("local_scale", Vector2.ONE) == next_scale:
		return false
	var before := _capture_document_snapshot()
	bone["local_position"] = next_position
	bone["local_rotation"] = next_rotation
	bone["local_scale"] = next_scale
	bones[bone_id] = bone
	rig["bones"] = bones
	_rigs[rig_id] = rig
	var label := description if not description.is_empty() else "Changed %s Bone Transform" % str(bone.get("name", bone_id))
	_commit_document_edit(before, label)
	return true


func set_rig_bone_length(rig_id: String, bone_id: String, length: float) -> bool:
	return _set_rig_bone_value(rig_id, bone_id, "length", maxf(1.0, length), "Changed Bone Length")


func set_rig_bone_visibility(rig_id: String, bone_id: String, visible: bool) -> bool:
	return _set_rig_bone_value(rig_id, bone_id, "visible", visible, ("Showed " if visible else "Hid ") + "Bone")


func set_rig_bone_locked(rig_id: String, bone_id: String, locked: bool) -> bool:
	return _set_rig_bone_value(rig_id, bone_id, "locked", locked, ("Locked " if locked else "Unlocked ") + "Bone")


func get_rig_bone_world_transform(rig_id: String, bone_id: String) -> Transform2D:
	if not _rigs.has(rig_id): return Transform2D.IDENTITY
	var manager = BoneManagerScript.new()
	manager.initialize(_rigs[rig_id] as Dictionary)
	return manager.get_global_transform(bone_id)


# === Animation authoring =====================================================

func get_animation_clips() -> Array:
	var clips: Array = []
	var store := _animation_store()
	for clip_id in store:
		var clip: Dictionary = (store[clip_id] as Dictionary).duplicate(true)
		if str(clip.get("clip_id", "")).is_empty(): clip["clip_id"] = str(clip_id)
		clips.append(clip)
	clips.sort_custom(func(a: Dictionary, b: Dictionary): return str(a.get("clip_name", a.get("clip_id", ""))).naturalnocasecmp_to(str(b.get("clip_name", b.get("clip_id", "")))) < 0)
	return clips


func get_active_animation_id() -> String:
	return str(manifest.get("metadata", {}).get("character_authoring", {}).get("active_animation_id", ""))


func get_active_animation_clip() -> Dictionary:
	return get_animation_clip(get_active_animation_id())


func get_animation_clip(clip_id: String) -> Dictionary:
	var store := _animation_store()
	return (store.get(clip_id, {}) as Dictionary).duplicate(true)


func set_active_animation_id(clip_id: String) -> bool:
	var store := _animation_store()
	if not clip_id.is_empty() and not store.has(clip_id): return false
	var authoring: Dictionary = manifest.get("metadata", {}).get("character_authoring", {}).duplicate(true)
	if str(authoring.get("active_animation_id", "")) == clip_id: return false
	authoring["active_animation_id"] = clip_id
	manifest.metadata["character_authoring"] = authoring
	session_changed.emit("Selected " + (str((store[clip_id] as Dictionary).get("clip_name", clip_id)) if not clip_id.is_empty() else "no animation"))
	return true


func create_animation_clip(display_name: String = "New Animation") -> Dictionary:
	if is_read_only(): return _failure("Bundled samples are read-only. Use Save As before creating an animation.")
	var name := display_name.strip_edges()
	if name.is_empty(): name = "New Animation"
	var before := _capture_document_snapshot()
	var clip_id: String = IDService.generate_id("anim")
	var clip = AnimationClipScript.new(clip_id, name)
	var store := _animation_store()
	store[clip_id] = clip.to_dict()
	manifest.objects["animations"] = store
	var authoring: Dictionary = manifest.metadata.character_authoring.duplicate(true)
	authoring["active_animation_id"] = clip_id
	manifest.metadata["character_authoring"] = authoring
	_commit_document_edit(before, "Created %s Animation" % name)
	return {"success": true, "errors": [], "clip_id": clip_id}


func update_animation_clip(clip_id: String, updates: Dictionary, description: String = "Changed Animation") -> bool:
	if is_read_only(): return false
	var store := _animation_store()
	if not store.has(clip_id): return false
	var clip: Dictionary = store[clip_id]
	var next := clip.duplicate(true)
	for key in updates:
		match str(key):
			"clip_name": next[key] = str(updates[key]).strip_edges()
			"duration": next[key] = maxf(0.01, float(updates[key]))
			"fps": next[key] = maxf(1.0, float(updates[key]))
			"loop_mode": next[key] = clampi(int(updates[key]), 0, 2)
			"notes": next[key] = str(updates[key])
	if str(next.get("clip_name", "")).is_empty(): return false
	if next == clip: return false
	var before := _capture_document_snapshot()
	store[clip_id] = next
	manifest.objects["animations"] = store
	_commit_document_edit(before, description)
	return true


func set_animation_loop_region(clip_id: String, region_id: String = "") -> bool:
	if is_read_only(): return false
	var store := _animation_store()
	if not store.has(clip_id): return false
	var clip: Dictionary = store[clip_id]
	var selected := ""
	if not region_id.is_empty():
		for raw_region in clip.get("regions", []):
			if str((raw_region as Dictionary).get("region_id", "")) == region_id:
				selected = region_id
				break
		if selected.is_empty(): return false
	var next := clip.duplicate(true)
	next["loop_region_enabled"] = not selected.is_empty()
	next["loop_region_id"] = selected
	if next == clip: return false
	var before := _capture_document_snapshot()
	store[clip_id] = next
	manifest.objects["animations"] = store
	_commit_document_edit(before, "Set Animation Loop Region" if not selected.is_empty() else "Cleared Animation Loop Region")
	return true


func add_animation_marker(clip_id: String, display_name: String, time: float) -> Dictionary:
	if is_read_only(): return _failure("Bundled samples are read-only. Use Save As before adding markers.")
	var store := _animation_store()
	if not store.has(clip_id): return _failure("Choose an animation before adding a marker.")
	var clip: Dictionary = store[clip_id]
	var before := _capture_document_snapshot()
	var markers: Array = clip.get("markers", []).duplicate(true)
	var marker_id := IDService.generate_id("marker")
	markers.append({"marker_id": marker_id, "name": display_name.strip_edges() if not display_name.strip_edges().is_empty() else "Marker", "time": clampf(time, 0.0, maxf(0.01, float(clip.get("duration", 1.0))))})
	markers.sort_custom(func(a: Dictionary, b: Dictionary): return float(a.get("time", 0.0)) < float(b.get("time", 0.0)))
	clip["markers"] = markers
	store[clip_id] = clip
	manifest.objects["animations"] = store
	_commit_document_edit(before, "Added Timeline Marker")
	return {"success": true, "errors": [], "marker_id": marker_id}


func update_animation_marker(clip_id: String, marker_id: String, updates: Dictionary) -> bool:
	return _update_timeline_annotation(clip_id, "markers", "marker_id", marker_id, updates, "Changed Timeline Marker")


func delete_animation_marker(clip_id: String, marker_id: String) -> bool:
	return _delete_timeline_annotation(clip_id, "markers", "marker_id", marker_id, "Deleted Timeline Marker")


func add_animation_region(clip_id: String, display_name: String, start_time: float, end_time: float) -> Dictionary:
	if is_read_only(): return _failure("Bundled samples are read-only. Use Save As before adding regions.")
	var store := _animation_store()
	if not store.has(clip_id): return _failure("Choose an animation before adding a region.")
	var clip: Dictionary = store[clip_id]
	var duration := maxf(0.01, float(clip.get("duration", 1.0)))
	var start := clampf(minf(start_time, end_time), 0.0, duration)
	var finish := clampf(maxf(start_time, end_time), 0.0, duration)
	if finish <= start: finish = minf(duration, start + 1.0 / maxf(1.0, float(clip.get("fps", 24.0))))
	if finish <= start: return _failure("A timeline region needs a positive duration.")
	var before := _capture_document_snapshot()
	var regions: Array = clip.get("regions", []).duplicate(true)
	var region_id := IDService.generate_id("region")
	regions.append({"region_id": region_id, "name": display_name.strip_edges() if not display_name.strip_edges().is_empty() else "Region", "start_time": start, "end_time": finish})
	regions.sort_custom(func(a: Dictionary, b: Dictionary): return float(a.get("start_time", 0.0)) < float(b.get("start_time", 0.0)))
	clip["regions"] = regions
	store[clip_id] = clip
	manifest.objects["animations"] = store
	_commit_document_edit(before, "Added Timeline Region")
	return {"success": true, "errors": [], "region_id": region_id}


func update_animation_region(clip_id: String, region_id: String, updates: Dictionary) -> bool:
	return _update_timeline_annotation(clip_id, "regions", "region_id", region_id, updates, "Changed Timeline Region")


func delete_animation_region(clip_id: String, region_id: String) -> bool:
	return _delete_timeline_annotation(clip_id, "regions", "region_id", region_id, "Deleted Timeline Region")


func delete_animation_clip(clip_id: String) -> bool:
	if is_read_only(): return false
	var store := _animation_store()
	if not store.has(clip_id): return false
	var name := str((store[clip_id] as Dictionary).get("clip_name", clip_id))
	var before := _capture_document_snapshot()
	store.erase(clip_id)
	manifest.objects["animations"] = store
	var authoring: Dictionary = manifest.metadata.character_authoring.duplicate(true)
	if str(authoring.get("active_animation_id", "")) == clip_id:
		var remaining: Array = store.keys()
		remaining.sort()
		authoring["active_animation_id"] = str(remaining[0]) if not remaining.is_empty() else ""
	manifest.metadata["character_authoring"] = authoring
	_commit_document_edit(before, "Deleted %s Animation" % name)
	return true


func add_animation_track(clip_id: String, object_id: String, property_path: String, display_name: String = "", track_type: int = TrackDefinitionScript.TrackType.ATTRIBUTE) -> Dictionary:
	if is_read_only(): return _failure("Bundled samples are read-only. Use Save As before editing animation tracks.")
	if object_id.is_empty() or property_path.is_empty(): return _failure("Choose an object and property before adding a track.")
	var store := _animation_store()
	if not store.has(clip_id): return _failure("Choose an animation before adding a track.")
	var clip: Dictionary = store[clip_id]
	for raw_track in clip.get("tracks", []):
		var existing: Dictionary = raw_track
		if str(existing.get("object_id", "")) == object_id and str(existing.get("property_path", "")) == property_path:
			return _failure("This object already has that animation track.")
	var before := _capture_document_snapshot()
	var track_id: String = IDService.generate_id("track")
	var track = TrackDefinitionScript.new(track_id, object_id, property_path)
	track.track_type = track_type
	track.display_name = display_name if not display_name.strip_edges().is_empty() else property_path
	var tracks: Array = clip.get("tracks", []).duplicate(true)
	var serialized_track := track.to_dict()
	if track_type == TrackDefinitionScript.TrackType.SCRIPT_PARAMETER:
		var parameter_segments := property_path.split(".", false)
		serialized_track["parameter_name"] = str(parameter_segments[parameter_segments.size() - 1]) if not parameter_segments.is_empty() else ""
		if str(serialized_track.get("parameter_name", "")).is_empty(): serialized_track["parameter_name"] = "parameter"
		serialized_track["value_type"] = "variant"
	tracks.append(serialized_track)
	clip["tracks"] = tracks
	store[clip_id] = clip
	manifest.objects["animations"] = store
	_commit_document_edit(before, "Added %s Track" % track.display_name)
	return {"success": true, "errors": [], "track_id": track_id}


func delete_animation_track(clip_id: String, track_id: String) -> bool:
	if is_read_only(): return false
	var store := _animation_store()
	if not store.has(clip_id): return false
	var clip: Dictionary = store[clip_id]
	var tracks: Array = clip.get("tracks", []).duplicate(true)
	var removed_name := "Track"
	for index in range(tracks.size()):
		var track: Dictionary = tracks[index]
		if str(track.get("track_id", "")) == track_id:
			removed_name = str(track.get("display_name", track_id))
			var before := _capture_document_snapshot()
			tracks.remove_at(index)
			clip["tracks"] = tracks
			store[clip_id] = clip
			manifest.objects["animations"] = store
			_commit_document_edit(before, "Deleted %s Track" % removed_name)
			return true
	return false


func set_animation_track_rotation_mode(clip_id: String, track_id: String, mode: String) -> bool:
	if is_read_only(): return false
	var normalized := mode.strip_edges().to_lower()
	if normalized not in ["shortest", "continuous", "clockwise", "counter_clockwise"]: return false
	var store := _animation_store()
	if not store.has(clip_id): return false
	var clip: Dictionary = store[clip_id]
	var tracks: Array = clip.get("tracks", []).duplicate(true)
	for index in range(tracks.size()):
		var track: Dictionary = tracks[index]
		if str(track.get("track_id", "")) != track_id: continue
		if int(track.get("track_type", TrackDefinitionScript.TrackType.ATTRIBUTE)) != TrackDefinitionScript.TrackType.TRANSFORM_ROTATION:
			return false
		if str(track.get("rotation_mode", "shortest")) == normalized: return false
		var before := _capture_document_snapshot()
		track["rotation_mode"] = normalized
		tracks[index] = track
		clip["tracks"] = tracks
		store[clip_id] = clip
		manifest.objects["animations"] = store
		_commit_document_edit(before, "Changed Rotation Interpolation")
		return true
	return false


func add_animation_key(clip_id: String, track_id: String, time: float, value: Variant) -> Dictionary:
	if is_read_only(): return _failure("Bundled samples are read-only. Use Save As before adding a keyframe.")
	var store := _animation_store()
	if not store.has(clip_id): return _failure("Choose an animation before adding a keyframe.")
	var clip: Dictionary = store[clip_id]
	var tracks: Array = clip.get("tracks", []).duplicate(true)
	for index in range(tracks.size()):
		var track: Dictionary = tracks[index]
		if str(track.get("track_id", "")) != track_id: continue
		if bool(track.get("locked", false)): return _failure("Unlock the track before adding a keyframe.")
		var before := _capture_document_snapshot()
		var key_time := clampf(time, 0.0, maxf(0.01, float(clip.get("duration", 1.0))))
		var keys: Array = track.get("keys", []).duplicate(true)
		for key_index in range(keys.size() - 1, -1, -1):
			if absf(float((keys[key_index] as Dictionary).get("time", -1.0)) - key_time) <= 0.0001: keys.remove_at(key_index)
		var key_id: String = IDService.generate_id("key")
		keys.append({"key_id": key_id, "time": key_time, "value": _json_safe_variant(value), "interpolation": 1})
		keys.sort_custom(func(a: Dictionary, b: Dictionary): return float(a.get("time", 0.0)) < float(b.get("time", 0.0)))
		track["keys"] = keys
		tracks[index] = track
		clip["tracks"] = tracks
		store[clip_id] = clip
		manifest.objects["animations"] = store
		_commit_document_edit(before, "Added Keyframe to %s" % str(track.get("display_name", track_id)))
		return {"success": true, "errors": [], "key_id": key_id}
	return _failure("The selected animation track no longer exists.")


func set_or_add_animation_key(clip_id: String, track_id: String, time: float, value: Variant, description: String = "Changed Keyframe") -> Dictionary:
	if is_read_only(): return _failure("Bundled samples are read-only. Use Save As before editing keyframes.")
	var store := _animation_store()
	if not store.has(clip_id): return _failure("Choose an animation before adding a keyframe.")
	var clip: Dictionary = store[clip_id]
	var tracks: Array = clip.get("tracks", []).duplicate(true)
	for index in range(tracks.size()):
		var track: Dictionary = tracks[index]
		if str(track.get("track_id", "")) != track_id: continue
		if bool(track.get("locked", false)): return _failure("Unlock the track before changing keyframes.")
		var key_time := clampf(time, 0.0, maxf(0.01, float(clip.get("duration", 1.0))))
		var keys: Array = track.get("keys", []).duplicate(true)
		var key_id := ""
		for key_index in range(keys.size()):
			var key: Dictionary = keys[key_index]
			if absf(float(key.get("time", -1.0)) - key_time) > 0.0001: continue
			key_id = str(key.get("key_id", ""))
			var next_value: Variant = _json_safe_variant(value)
			if key.get("value") == next_value: return {"success": true, "errors": [], "key_id": key_id, "unchanged": true}
			var before_existing := _capture_document_snapshot()
			key["value"] = next_value
			keys[key_index] = key
			track["keys"] = keys
			tracks[index] = track
			clip["tracks"] = tracks
			store[clip_id] = clip
			manifest.objects["animations"] = store
			_commit_document_edit(before_existing, description)
			return {"success": true, "errors": [], "key_id": key_id, "updated": true}
		return add_animation_key(clip_id, track_id, key_time, value)
	return _failure("The selected animation track no longer exists.")


func set_animation_key_interpolation(clip_id: String, track_id: String, key_id: String, interpolation: int, out_handle: Variant = null, in_handle: Variant = null) -> bool:
	if is_read_only(): return false
	var store := _animation_store()
	if not store.has(clip_id): return false
	var clip: Dictionary = store[clip_id]
	var tracks: Array = clip.get("tracks", []).duplicate(true)
	for track_index in range(tracks.size()):
		var track: Dictionary = tracks[track_index]
		if str(track.get("track_id", "")) != track_id or bool(track.get("locked", false)): continue
		var keys: Array = track.get("keys", []).duplicate(true)
		for key_index in range(keys.size()):
			var key: Dictionary = keys[key_index]
			if str(key.get("key_id", "")) != key_id: continue
			var next := key.duplicate(true)
			next["interpolation"] = clampi(interpolation, TrackDefinitionScript.Interpolation.STEPPED, TrackDefinitionScript.Interpolation.BEZIER)
			if out_handle != null: next["out_handle"] = _json_safe_variant(out_handle)
			if in_handle != null: next["in_handle"] = _json_safe_variant(in_handle)
			if next == key: return false
			var before := _capture_document_snapshot()
			keys[key_index] = next
			track["keys"] = keys
			tracks[track_index] = track
			clip["tracks"] = tracks
			store[clip_id] = clip
			manifest.objects["animations"] = store
			_commit_document_edit(before, "Changed Keyframe Interpolation")
			return true
	return false


func edit_animation_keys_batch(clip_id: String, edits: Array, description: String = "Edited Keyframes") -> Dictionary:
	if is_read_only(): return _failure("Bundled samples are read-only. Use Save As before editing keyframes.")
	var store := _animation_store()
	if not store.has(clip_id): return _failure("Choose an animation before editing keys.")
	var clip: Dictionary = store[clip_id]
	var tracks: Array = clip.get("tracks", []).duplicate(true)
	var before := _capture_document_snapshot()
	var changed := 0
	for raw_edit in edits:
		if not (raw_edit is Dictionary): continue
		var edit: Dictionary = raw_edit
		var track_id := str(edit.get("track_id", ""))
		var key_id := str(edit.get("key_id", ""))
		for track_index in range(tracks.size()):
			var track: Dictionary = tracks[track_index]
			if str(track.get("track_id", "")) != track_id or bool(track.get("locked", false)): continue
			var keys: Array = track.get("keys", []).duplicate(true)
			for key_index in range(keys.size()):
				var key: Dictionary = keys[key_index]
				if str(key.get("key_id", "")) != key_id: continue
				var next := key.duplicate(true)
				if edit.has("time"): next["time"] = clampf(float(edit.get("time", 0.0)), 0.0, maxf(0.01, float(clip.get("duration", 1.0))))
				if edit.has("value"): next["value"] = _json_safe_variant(edit.get("value"))
				if edit.has("interpolation"): next["interpolation"] = clampi(int(edit.get("interpolation", 1)), 0, TrackDefinitionScript.Interpolation.BEZIER)
				if edit.has("out_handle"): next["out_handle"] = _json_safe_variant(edit.get("out_handle"))
				if edit.has("in_handle"): next["in_handle"] = _json_safe_variant(edit.get("in_handle"))
				if next == key: continue
				keys[key_index] = next
				keys.sort_custom(func(a: Dictionary, b: Dictionary): return float(a.get("time", 0.0)) < float(b.get("time", 0.0)))
				track["keys"] = keys
				tracks[track_index] = track
				changed += 1
				break
			break
	if changed == 0: return {"success": true, "errors": [], "changed": 0}
	clip["tracks"] = tracks
	store[clip_id] = clip
	manifest.objects["animations"] = store
	_commit_document_edit(before, description)
	return {"success": true, "errors": [], "changed": changed}


func paste_animation_keys(clip_id: String, entries: Array, at_time: float) -> Dictionary:
	if is_read_only(): return _failure("Bundled samples are read-only. Use Save As before pasting keyframes.")
	var store := _animation_store()
	if not store.has(clip_id): return _failure("Choose an animation before pasting keyframes.")
	var clip: Dictionary = store[clip_id]
	var tracks: Array = clip.get("tracks", []).duplicate(true)
	var before := _capture_document_snapshot()
	var pasted := 0
	for raw_entry in entries:
		if not (raw_entry is Dictionary): continue
		var entry: Dictionary = raw_entry
		var source: Dictionary = entry.get("key", {}) as Dictionary
		var target_track_id := str(entry.get("track_id", ""))
		for track_index in range(tracks.size()):
			var track: Dictionary = tracks[track_index]
			if str(track.get("track_id", "")) != target_track_id or bool(track.get("locked", false)): continue
			var target_time := clampf(at_time + float(entry.get("offset", 0.0)), 0.0, maxf(0.01, float(clip.get("duration", 1.0))))
			var keys: Array = track.get("keys", []).duplicate(true)
			for key_index in range(keys.size() - 1, -1, -1):
				if absf(float((keys[key_index] as Dictionary).get("time", -1.0)) - target_time) <= 0.0001: keys.remove_at(key_index)
			var next := source.duplicate(true)
			next["key_id"] = IDService.generate_id("key")
			next["time"] = target_time
			keys.append(next)
			keys.sort_custom(func(a: Dictionary, b: Dictionary): return float(a.get("time", 0.0)) < float(b.get("time", 0.0)))
			track["keys"] = keys
			tracks[track_index] = track
			pasted += 1
			break
	if pasted == 0: return {"success": false, "errors": ["No unlocked target tracks were available for pasting."], "pasted": 0}
	clip["tracks"] = tracks
	store[clip_id] = clip
	manifest.objects["animations"] = store
	_commit_document_edit(before, "Pasted %d Keyframe%s" % [pasted, "s" if pasted != 1 else ""])
	return {"success": true, "errors": [], "pasted": pasted}


func move_animation_key(clip_id: String, track_id: String, key_id: String, time: float) -> bool:
	if is_read_only(): return false
	var store := _animation_store()
	if not store.has(clip_id): return false
	var clip: Dictionary = store[clip_id]
	var tracks: Array = clip.get("tracks", []).duplicate(true)
	for index in range(tracks.size()):
		var track: Dictionary = tracks[index]
		if str(track.get("track_id", "")) != track_id or bool(track.get("locked", false)): continue
		var keys: Array = track.get("keys", []).duplicate(true)
		for key_index in range(keys.size()):
			var key: Dictionary = keys[key_index]
			if str(key.get("key_id", "")) != key_id: continue
			var next_time := clampf(time, 0.0, maxf(0.01, float(clip.get("duration", 1.0))))
			if is_equal_approx(float(key.get("time", 0.0)), next_time): return false
			var before := _capture_document_snapshot()
			key["time"] = next_time
			keys[key_index] = key
			keys.sort_custom(func(a: Dictionary, b: Dictionary): return float(a.get("time", 0.0)) < float(b.get("time", 0.0)))
			track["keys"] = keys
			tracks[index] = track
			clip["tracks"] = tracks
			store[clip_id] = clip
			manifest.objects["animations"] = store
			_commit_document_edit(before, "Moved Keyframe on %s" % str(track.get("display_name", track_id)))
			return true
	return false


func set_animation_key_value(clip_id: String, track_id: String, key_id: String, value: Variant) -> bool:
	if is_read_only(): return false
	var store := _animation_store()
	if not store.has(clip_id): return false
	var clip: Dictionary = store[clip_id]
	var tracks: Array = clip.get("tracks", []).duplicate(true)
	for index in range(tracks.size()):
		var track: Dictionary = tracks[index]
		if str(track.get("track_id", "")) != track_id or bool(track.get("locked", false)): continue
		var keys: Array = track.get("keys", []).duplicate(true)
		for key_index in range(keys.size()):
			var key: Dictionary = keys[key_index]
			if str(key.get("key_id", "")) != key_id: continue
			var next_value: Variant = _json_safe_variant(value)
			if key.get("value") == next_value: return false
			var before := _capture_document_snapshot()
			key["value"] = next_value
			keys[key_index] = key
			track["keys"] = keys
			tracks[index] = track
			clip["tracks"] = tracks
			store[clip_id] = clip
			manifest.objects["animations"] = store
			_commit_document_edit(before, "Changed Keyframe Value on %s" % str(track.get("display_name", track_id)))
			return true
	return false


func delete_animation_key(clip_id: String, track_id: String, key_id: String) -> bool:
	if is_read_only(): return false
	var store := _animation_store()
	if not store.has(clip_id): return false
	var clip: Dictionary = store[clip_id]
	var tracks: Array = clip.get("tracks", []).duplicate(true)
	for index in range(tracks.size()):
		var track: Dictionary = tracks[index]
		if str(track.get("track_id", "")) != track_id: continue
		var keys: Array = track.get("keys", []).duplicate(true)
		for key_index in range(keys.size()):
			if str((keys[key_index] as Dictionary).get("key_id", "")) != key_id: continue
			var before := _capture_document_snapshot()
			keys.remove_at(key_index)
			track["keys"] = keys
			tracks[index] = track
			clip["tracks"] = tracks
			store[clip_id] = clip
			manifest.objects["animations"] = store
			_commit_document_edit(before, "Deleted Keyframe from %s" % str(track.get("display_name", track_id)))
			return true
	return false


func get_animation_track(clip_id: String, track_id: String) -> Dictionary:
	var clip := get_animation_clip(clip_id)
	for raw_track in clip.get("tracks", []):
		var track: Dictionary = raw_track
		if str(track.get("track_id", "")) == track_id: return track.duplicate(true)
	return {}


func _update_timeline_annotation(clip_id: String, collection_name: String, id_name: String, item_id: String, updates: Dictionary, description: String) -> bool:
	if is_read_only(): return false
	var store := _animation_store()
	if not store.has(clip_id): return false
	var clip: Dictionary = store[clip_id]
	var items: Array = clip.get(collection_name, []).duplicate(true)
	for index in range(items.size()):
		var item: Dictionary = items[index]
		if str(item.get(id_name, "")) != item_id: continue
		var next := item.duplicate(true)
		for key in updates:
			match str(key):
				"name": next[key] = str(updates[key]).strip_edges()
				"time", "start_time", "end_time": next[key] = maxf(0.0, float(updates[key]))
		if collection_name == "regions" and float(next.get("end_time", 0.0)) <= float(next.get("start_time", 0.0)): return false
		if next == item: return false
		var before := _capture_document_snapshot()
		items[index] = next
		clip[collection_name] = items
		store[clip_id] = clip
		manifest.objects["animations"] = store
		_commit_document_edit(before, description)
		return true
	return false


func _delete_timeline_annotation(clip_id: String, collection_name: String, id_name: String, item_id: String, description: String) -> bool:
	if is_read_only(): return false
	var store := _animation_store()
	if not store.has(clip_id): return false
	var clip: Dictionary = store[clip_id]
	var items: Array = clip.get(collection_name, []).duplicate(true)
	for index in range(items.size()):
		if str((items[index] as Dictionary).get(id_name, "")) != item_id: continue
		var before := _capture_document_snapshot()
		items.remove_at(index)
		clip[collection_name] = items
		if collection_name == "regions" and str(clip.get("loop_region_id", "")) == item_id:
			clip["loop_region_id"] = ""
			clip["loop_region_enabled"] = false
		store[clip_id] = clip
		manifest.objects["animations"] = store
		_commit_document_edit(before, description)
		return true
	return false


func _set_rig_bone_value(rig_id: String, bone_id: String, property_name: String, value: Variant, description: String) -> bool:
	if is_read_only() or not _rigs.has(rig_id): return false
	var rig: Dictionary = _rigs[rig_id]
	var bones: Dictionary = rig.get("bones", {})
	if not bones.has(bone_id): return false
	var bone: Dictionary = bones[bone_id]
	if bone.get(property_name) == value: return false
	var before := _capture_document_snapshot()
	bone[property_name] = value
	bones[bone_id] = bone
	rig["bones"] = bones
	_rigs[rig_id] = rig
	_commit_document_edit(before, description)
	return true


func _remove_bone_from_rig(rig: Dictionary, bone_id: String) -> void:
	var bones: Dictionary = rig.get("bones", {})
	if not bones.has(bone_id): return
	var bone: Dictionary = bones[bone_id]
	for child_id in (bone.get("children", []) as Array).duplicate():
		_remove_bone_from_rig(rig, str(child_id))
	bones = rig.get("bones", {})
	var parent_id := str(bone.get("parent_id", ""))
	if not parent_id.is_empty() and bones.has(parent_id):
		var parent: Dictionary = bones[parent_id]
		var children: Array = parent.get("children", []).duplicate()
		children.erase(bone_id)
		parent["children"] = children
		bones[parent_id] = parent
	bones.erase(bone_id)
	rig["bones"] = bones
	if str(rig.get("root_bone_id", "")) == bone_id:
		rig["root_bone_id"] = _find_first_root_bone_id(bones)


func _find_first_root_bone_id(bones: Dictionary) -> String:
	var bone_ids: Array = bones.keys()
	bone_ids.sort()
	for bone_id in bone_ids:
		if str((bones[bone_id] as Dictionary).get("parent_id", "")).is_empty(): return str(bone_id)
	return ""


func _animation_store() -> Dictionary:
	var objects: Dictionary = manifest.get("objects", {})
	if not objects.has("animations") or typeof(objects.get("animations")) != TYPE_DICTIONARY:
		objects["animations"] = {}
		manifest["objects"] = objects
	return objects["animations"] as Dictionary


func _json_safe_variant(value: Variant) -> Variant:
	if value is Vector2:
		var vector: Vector2 = value
		return [vector.x, vector.y]
	if value is Color:
		var color: Color = value
		return [color.r, color.g, color.b, color.a]
	if value is Dictionary:
		var result := {}
		for key in (value as Dictionary): result[key] = _json_safe_variant((value as Dictionary)[key])
		return result
	if value is Array:
		var result: Array = []
		for entry in (value as Array): result.append(_json_safe_variant(entry))
		return result
	return value


func _ensure_authoring_data() -> void:
	if not manifest.has("objects"): manifest["objects"] = {}
	for category in ["characters", "body_types", "assets", "rigs", "animations"]:
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
	if not authoring.has("active_rig_id"): authoring["active_rig_id"] = ""
	if not authoring.has("active_animation_id"): authoring["active_animation_id"] = ""
	if not authoring.has("workflow"):
		authoring["workflow"] = {"new_project": false, "completed": true, "current_step": 0, "deferred": false}
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


func _hydrate_rigs() -> void:
	_rigs.clear()
	var serialized: Dictionary = manifest.get("objects", {}).get("rigs", {}) as Dictionary
	for rig_id in serialized:
		var raw: Dictionary = serialized[rig_id] as Dictionary
		var rig: Dictionary = RigSchemaScript.from_json_dict(raw)
		if str(rig.get("id", "")).is_empty(): rig["id"] = str(rig_id)
		_rigs[str(rig.get("id", rig_id))] = rig
	var authoring: Dictionary = manifest.get("metadata", {}).get("character_authoring", {}) as Dictionary
	var active_id := str(authoring.get("active_rig_id", ""))
	if not active_id.is_empty() and not _rigs.has(active_id):
		authoring["active_rig_id"] = ""
		manifest.metadata["character_authoring"] = authoring


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
	var serialized_rigs := {}
	for rig_id in _rigs:
		serialized_rigs[rig_id] = RigSchemaScript.to_json_dict(_rigs[rig_id] as Dictionary)
	manifest.objects["rigs"] = serialized_rigs
	manifest["modified_at"] = Time.get_unix_time_from_system()


func _copy_into_project(source_path: String, part_id: String) -> String:
	return _copy_asset_into_project(source_path, part_id, "character_parts")


func _copy_asset_into_project(source_path: String, asset_id: String, folder: String) -> String:
	var asset_dir := _asset_root_for_project(project_path).path_join(folder)
	var absolute_dir := ProjectSettings.globalize_path(asset_dir)
	if DirAccess.make_dir_recursive_absolute(absolute_dir) != OK and not DirAccess.dir_exists_absolute(absolute_dir): return ""
	var target := asset_dir.path_join(asset_id + "_" + source_path.get_file().validate_filename())
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
	_hydrate_rigs()
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


func _issue_messages(issues: Array) -> Array:
	var messages: Array = []
	for raw_issue in issues:
		if raw_issue is Dictionary:
			messages.append(str((raw_issue as Dictionary).get("message", "Import check failed.")))
		else:
			messages.append(str(raw_issue))
	return messages if not messages.is_empty() else ["Import check failed."]
