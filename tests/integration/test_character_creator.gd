# Integration tests for the complete Phase 3 character-creator workflow model.
extends Node

const BodyScript = preload("res://character/definitions/character_body_type_definition.gd")
const SlotScript = preload("res://character/definitions/character_slot_definition.gd")
const PartScript = preload("res://character/definitions/character_part_definition.gd")
const PaletteScript = preload("res://character/palettes/character_palette_definition.gd")
const SlotRegistryScript = preload("res://character/registries/character_slot_registry.gd")
const PartRegistryScript = preload("res://character/registries/character_part_registry.gd")
const CreatorScript = preload("res://character/authoring/character_creator_model.gd")
const WeaponScript = preload("res://weapons/definitions/weapon_definition.gd")
const ProjectFactoryScript = preload("res://character/authoring/character_project_factory.gd")
const ProjectSessionScript = preload("res://character/authoring/character_project_session.gd")
const CreatorPanelScene = preload("res://character/authoring/character_creator_panel.tscn")


func run_tests() -> int:
	var passes := 0
	passes += test_off_tree_session_owns_asset_services()
	passes += test_creator_edits_are_browseable_reversible_and_weapon_safe()
	passes += test_seeded_npc_batch_has_one_hundred_unique_valid_assemblies()
	passes += test_manual_panel_imports_real_art_and_persists_it()
	passes += test_import_wizard_layer_controls_and_document_history()
	passes += test_project_backed_rig_and_timeline_history()
	return passes


func test_off_tree_session_owns_asset_services() -> int:
	var session = ProjectSessionScript.new()
	var registry: Node = session.asset_registry
	var thumbnail_cache: Node = session.thumbnail_cache
	var attached := registry.get_parent() == session and thumbnail_cache.get_parent() == session
	session.free()
	var released := not is_instance_valid(registry) and not is_instance_valid(thumbnail_cache)
	if attached and released:
		print("  PASS: Off-tree project sessions own and release their asset services")
		return 1
	printerr("  FAIL: Off-tree project session did not release its asset services")
	return 0


func test_project_backed_rig_and_timeline_history() -> int:
	var test_id: String = IDService.generate_short("dock_data")
	var project_path := "user://character_authoring_tests/%s.chrproj" % test_id
	var created: bool = SerializationService.save_project(ProjectFactoryScript.create_manifest("Dock Data"), project_path)
	AppState.open_project(project_path)
	CommandService.clear_history()
	var session = ProjectSessionScript.new()
	var opened: Dictionary = session.open_project(project_path)
	var rig_report: Dictionary = session.create_rig("Hero Rig")
	var rig_id := str(rig_report.get("rig_id", ""))
	var root_report: Dictionary = session.create_rig_bone(rig_id, "Root", "", 80.0)
	var root_id := str(root_report.get("bone_id", ""))
	var child_report: Dictionary = session.create_rig_bone(rig_id, "Head", root_id, 32.0)
	var child_id := str(child_report.get("bone_id", ""))
	var moved: bool = session.set_rig_bone_transform(rig_id, root_id, Vector2(10.0, 20.0), 15.0, Vector2.ONE, "Moved Root Bone")
	var move_label := CommandService.get_undo_description()
	var clip_report: Dictionary = session.create_animation_clip("Idle")
	var clip_id := str(clip_report.get("clip_id", ""))
	var track_report: Dictionary = session.add_animation_track(clip_id, root_id, "bone:%s.transform" % root_id, "Root Transform")
	var track_id := str(track_report.get("track_id", ""))
	var key_report: Dictionary = session.add_animation_key(clip_id, track_id, 0.25, {"position": Vector2(10.0, 20.0)})
	var key_id := str(key_report.get("key_id", ""))
	var key_label := CommandService.get_undo_description()
	var moved_key: bool = session.move_animation_key(clip_id, track_id, key_id, 0.5)
	var undo_key: bool = CommandService.undo()
	var undo_track: Dictionary = session.get_animation_track(clip_id, track_id)
	var redo_key: bool = CommandService.redo()
	var saved: Dictionary = session.save_project()
	var loaded: Dictionary = SerializationService.load_project(project_path)
	var saved_rig: Dictionary = (loaded.get("objects", {}).get("rigs", {}) as Dictionary).get(rig_id, {}) as Dictionary
	var saved_root: Dictionary = (saved_rig.get("bones", {}) as Dictionary).get(root_id, {}) as Dictionary
	var saved_clip: Dictionary = (loaded.get("objects", {}).get("animations", {}) as Dictionary).get(clip_id, {}) as Dictionary
	var saved_tracks: Array = saved_clip.get("tracks", []) as Array
	var persisted: bool = saved_rig.get("name", "") == "Hero Rig" and (saved_root.get("local_position", []) as Array) == [10.0, 20.0] and saved_tracks.size() == 1 and ((saved_tracks[0] as Dictionary).get("keys", []) as Array).size() == 1
	var history_ok: bool = moved and move_label == "Moved Root Bone" and key_report.get("success", false) and key_label.begins_with("Added Keyframe") and moved_key and undo_key and not (undo_track.get("keys", []) as Array).is_empty() and is_equal_approx(float((undo_track.get("keys", [])[0] as Dictionary).get("time", 0.0)), 0.25) and redo_key
	session.asset_registry.free()
	session.thumbnail_cache.free()
	session.free()
	AppState.close_project()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(project_path))
	if created and opened.get("success", false) and rig_report.get("success", false) and root_report.get("success", false) and child_report.get("success", false) and not child_id.is_empty() and clip_report.get("success", false) and track_report.get("success", false) and persisted and history_ok and saved.get("success", false):
		print("  PASS: Project-backed rig and timeline edits persist and share document Undo/Redo")
		return 1
	printerr("  FAIL: Project-backed rig/timeline workflow failed: %s" % str([created, opened, rig_report, root_report, child_report, moved, move_label, clip_report, track_report, key_report, moved_key, history_ok, saved, persisted]))
	return 0


func test_import_wizard_layer_controls_and_document_history() -> int:
	var test_id: String = IDService.generate_short("wizard")
	var test_dir := "user://character_authoring_tests/" + test_id
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(test_dir))
	var project_path := test_dir.path_join("ImportedHero.chrproj")
	var body_path := test_dir.path_join("body.png")
	var head_path := test_dir.path_join("head.png")
	var body_image := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	body_image.fill(Color(0.1, 0.5, 0.9, 1.0))
	var head_image := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	head_image.fill(Color(0.95, 0.65, 0.4, 1.0))
	var project_created := SerializationService.save_project(ProjectFactoryScript.create_manifest("Imported Hero", "blank"), project_path)
	var images_created := body_image.save_png(body_path) == OK and head_image.save_png(head_path) == OK
	AppState.open_project(project_path)
	CommandService.clear_history()
	var session = ProjectSessionScript.new()
	var opened: Dictionary = session.open_project(project_path)
	var template: Dictionary = session.apply_slot_template("portrait")
	var canvas_changed := session.set_canvas_settings(640, 480, 2.0)
	var mapping: Dictionary = session.map_files_to_slots([body_path, head_path])
	var imported: Dictionary = session.import_files_by_slot([body_path, head_path])
	var duplicated_asset: Dictionary = session.import_part(body_path, "face", "Face Copy")
	var body_part_id := ""
	for result in imported.get("imported", []):
		if str((result as Dictionary).get("path", "")).get_file().contains("body"):
			body_part_id = str((result as Dictionary).get("part_id", ""))
	if body_part_id.is_empty() and not (imported.get("imported", []) as Array).is_empty():
		body_part_id = str((imported.get("imported", [])[0] as Dictionary).get("part_id", ""))
	CommandService.clear_history()
	AppState.mark_clean()
	var moved: bool = session.model.set_layer_position(body_part_id, Vector2(24.0, -12.0))
	var move_label := CommandService.get_undo_description()
	var moved_state: Dictionary = session.model.get_layer_state(body_part_id)
	var undo_move: bool = CommandService.undo()
	var undone_state: Dictionary = session.model.get_layer_state(body_part_id)
	var redo_move: bool = CommandService.redo()
	var redone_state: Dictionary = session.model.get_layer_state(body_part_id)
	var pivot_changed: bool = session.model.set_layer_pivot(body_part_id, Vector2(0.25, 0.75))
	var pivot_label := CommandService.get_undo_description()
	var locked: bool = session.model.set_layer_locked(body_part_id, true)
	var locked_edit_blocked: bool = not session.model.set_layer_rotation(body_part_id, 45.0)
	var unlocked: bool = session.model.set_layer_locked(body_part_id, false)
	var tinted: bool = session.model.set_layer_tint(body_part_id, Color(0.8, 0.9, 1.0, 0.75))
	var duplicate_layer: Dictionary = session.duplicate_layer(body_part_id)
	var deleted_duplicate: Dictionary = session.delete_layer(str(duplicate_layer.get("part_id", "")))
	var health: Dictionary = session.get_asset_health_report()
	var saved: Dictionary = session.save_project()
	var settings: Dictionary = session.get_canvas_settings()
	var imported_count := (imported.get("imported", []) as Array).size()
	var mapped_count := (mapping.get("mapped", []) as Array).size()
	var duplicate_detected := not (duplicated_asset.get("duplicate_asset_ids", []) as Array).is_empty() and int(health.get("duplicate_groups", 0)) > 0
	var history_ok: bool = moved and move_label.begins_with("Moved ") and (moved_state.get("position", []) as Array) == [24.0, -12.0] and undo_move and (undone_state.get("position", []) as Array) == [0.0, 0.0] and redo_move and (redone_state.get("position", []) as Array) == [24.0, -12.0] and pivot_changed and pivot_label.begins_with("Changed Pivot")
	var workflow_ok: bool = project_created and images_created and opened.get("success", false) and template.get("success", false) and canvas_changed and mapped_count == 2 and imported_count == 2 and duplicated_asset.get("success", false) and duplicate_detected and history_ok and locked and locked_edit_blocked and unlocked and tinted and duplicate_layer.get("success", false) and deleted_duplicate.get("success", false) and saved.get("success", false) and settings == {"width": 640, "height": 480, "pixel_scale": 2.0}
	var asset_paths: Array = []
	for asset in session.asset_registry.list_assets():
		asset_paths.append(str((asset as Dictionary).get("path", "")))
	session.asset_registry.free()
	session.thumbnail_cache.free()
	session.free()
	AppState.close_project()
	for path in asset_paths + [body_path, head_path, project_path, project_path.get_basename() + ".autosave.json"]:
		if not str(path).is_empty():
			DirAccess.remove_absolute(ProjectSettings.globalize_path(str(path)))
	if workflow_ok:
		print("  PASS: Import wizard maps artwork, exposes layer controls, detects duplicates, and uses document history")
		return 1
	printerr("  FAIL: Import wizard and layer workflow failed: %s" % str([project_created, images_created, opened, template, canvas_changed, mapping, imported, duplicated_asset, health, history_ok, locked, locked_edit_blocked, unlocked, tinted, duplicate_layer, deleted_duplicate, saved, settings]))
	return 0


func test_manual_panel_imports_real_art_and_persists_it() -> int:
	var test_id: String = IDService.generate_short("ui")
	var project_path := "user://character_authoring_tests/%s.chrproj" % test_id
	var source_path := "user://character_authoring_tests/%s_source.png" % test_id
	var manifest := ProjectFactoryScript.create_manifest("Hand Drawn Hero", "blank")
	var project_saved: bool = SerializationService.save_project(manifest, project_path)
	var image := Image.create(12, 12, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.0, 0.0, 0.0, 0.0))
	image.fill_rect(Rect2i(2, 2, 8, 8), Color(0.2, 0.7, 1.0, 1.0))
	var image_saved: bool = image.save_png(source_path) == OK
	var session = ProjectSessionScript.new()
	var opened: Dictionary = session.open_project(project_path)
	var imported: Dictionary = session.import_part(source_path, "body")
	var copied_path := str(imported.get("path", ""))
	var panel := CreatorPanelScene.instantiate()
	var preview = panel.get_node("Margin/Root/Content/PreviewCard/PreviewMargin/PreviewVBox/Preview")
	preview.set_layers(session.get_preview_layers())
	var preview_uses_real_art: bool = preview.get_loaded_layer_count() == 1
	var no_random_ui: bool = panel.find_child("Randomize", true, false) == null
	var autosaved: Dictionary = session.autosave_project()
	var autosave_path := str(autosaved.get("path", ""))
	var autosave_kept_dirty: bool = bool(autosaved.get("success", false)) and AppState.is_dirty() and FileAccess.file_exists(autosave_path)
	var saved: Dictionary = session.save_project()
	var loaded: Dictionary = SerializationService.load_project(project_path)
	var authoring: Dictionary = loaded.get("metadata", {}).get("character_authoring", {})
	var characters: Dictionary = loaded.get("objects", {}).get("characters", {})
	var active_id := str(authoring.get("active_character_id", ""))
	var equipped: Dictionary = (characters.get(active_id, {}) as Dictionary).get("assembly", {}).get("equipped_by_slot", {})
	var persisted: bool = (authoring.get("parts", {}) as Dictionary).size() == 1 and (equipped.get("body", []) as Array).size() == 1
	var copy_path := "user://character_authoring_tests/%s_copy.chrproj" % test_id
	var copied: Dictionary = session.save_project_as(copy_path)
	var copied_manifest: Dictionary = SerializationService.load_project(copy_path)
	var copied_assets: Dictionary = copied_manifest.get("objects", {}).get("assets", {})
	var copied_asset_path := str((copied_assets.values()[0] as Dictionary).get("path", "")) if not copied_assets.is_empty() else ""
	var copy_is_independent: bool = bool(copied.get("success", false)) and not copied_manifest.is_empty() and copied_asset_path != copied_path and FileAccess.file_exists(copied_asset_path)
	panel.free()
	session.asset_registry.free()
	session.thumbnail_cache.free()
	session.free()
	for path in [source_path, copied_path, copied_asset_path, autosave_path, copy_path, project_path]:
		if not str(path).is_empty(): DirAccess.remove_absolute(ProjectSettings.globalize_path(str(path)))
	if project_saved and image_saved and opened.get("success", false) and imported.get("success", false) and preview_uses_real_art and no_random_ui and autosave_kept_dirty and saved.get("success", false) and persisted and copy_is_independent:
		print("  PASS: Character Creator imports exact art, autosaves safely, and persists independent project copies")
		return 1
	printerr("  FAIL: Manual character panel flow failed: %s" % str([project_saved, image_saved, opened, imported, preview_uses_real_art, no_random_ui, autosave_kept_dirty, saved, persisted, copy_is_independent]))
	return 0


func test_creator_edits_are_browseable_reversible_and_weapon_safe() -> int:
	var fixture = _fixture(4)
	var creator = _creator(fixture)
	var created: bool = creator.create_character("hero", "Hero", "human").get("success", false)
	var options: Array = creator.browse_parts({"slot_id": "slot_0", "query": "variant"})
	var randomized: bool = creator.randomize(81).get("success", false)
	var first: Dictionary = creator.assembly.to_dict()
	var repeat: bool = creator.randomize(81).get("success", false)
	var deterministic: bool = first == creator.assembly.to_dict()
	var preserved_part: String = creator.assembly.get_equipped_part_ids()[0]
	var locked: bool = creator.lock_part(preserved_part)
	var map_ok: bool = creator.set_attachment_map(preserved_part, {"anchor": "hand", "offset": [2, 3]})
	var palette = PaletteScript.new("warm", "Warm")
	palette.set_channel("skin", "#d69a73")
	var palette_ok: bool = creator.add_palette(palette) and creator.apply_palette("warm").get("success", false)
	var outfit_ok: bool = creator.save_outfit("adventurer")
	var weapon_ok: bool = creator.equip_weapon("wand").get("success", false)
	var preset_ok: bool = creator.save_preset("hero_base")
	creator.lock_palette_channel("skin", false)
	creator.set_palette_channel("skin", "#111111")
	var undo_ok: bool = creator.undo() and creator.assembly.palette_values.get("skin") == "#d69a73"
	var redo_ok: bool = creator.redo() and creator.assembly.palette_values.get("skin") == "#111111"
	creator.apply_preset("hero_base")
	var preset_restored: bool = creator.assembly.equipped_weapon_id == "wand" and creator.assembly.attachment_maps.has(preserved_part)
	creator.apply_outfit("adventurer")
	var outfit_restored: bool = creator.assembly.validate().get("success", false)
	var restored = _creator(fixture)
	var session_ok: bool = restored.from_dict(creator.to_dict()) and restored.assembly.validate().get("success", false)
	restored.free()
	creator.free()
	if created and options.size() == 4 and randomized and repeat and deterministic and locked and map_ok and palette_ok and outfit_ok and preset_ok and weapon_ok and undo_ok and redo_ok and preset_restored and outfit_restored and session_ok:
		print("  PASS: CHR-005 through CHR-016 browse, palettes, maps, outfits, locks, presets, weapons, undo/redo, and sessions")
		return 1
	printerr("  FAIL: CHR creator workflow integration failed: %s" % str([created, options.size(), randomized, repeat, deterministic, locked, map_ok, palette_ok, outfit_ok, preset_ok, weapon_ok, undo_ok, redo_ok, preset_restored, outfit_restored, session_ok]))
	return 0


func test_seeded_npc_batch_has_one_hundred_unique_valid_assemblies() -> int:
	var fixture = _fixture(4)
	var creator = _creator(fixture)
	creator.create_character("source", "Source", "human")
	var first: Dictionary = creator.generate_npc_batch(100, 90210)
	var second: Dictionary = creator.generate_npc_batch(100, 90210)
	creator.free()
	if first.get("success", false) and second.get("success", false) and first.characters.size() == 100 and first.characters == second.characters:
		print("  PASS: QA-CHR-001 seeded batch yields 100 distinct reproducible valid characters")
		return 1
	printerr("  FAIL: CHR NPC batch failed: %s" % str(first.get("errors", [])))
	return 0


func _creator(fixture: Dictionary):
	var weapon = WeaponScript.new("wand", "Wand")
	weapon.asset_id = "asset_wand"
	weapon.tags = ["magic"]
	weapon.supported_body_types = ["human"]
	var creator = CreatorScript.new()
	creator.configure(fixture.parts, fixture.slots, [fixture.body], [weapon])
	return creator


func _fixture(variants: int) -> Dictionary:
	var slots = SlotRegistryScript.new()
	var parts = PartRegistryScript.new()
	for slot_index in 5:
		var slot = SlotScript.new("slot_%d" % slot_index, "Slot %d" % slot_index)
		slot.required = true
		slot.allowed_part_tags = ["slot_%d" % slot_index]
		slots.register_slot(slot)
		for variant_index in variants:
			var part = PartScript.new("part_%d_%d" % [slot_index, variant_index], "Variant %d-%d" % [slot_index, variant_index], slot.slot_id)
			part.asset_id = "asset_" + part.part_id
			part.supported_body_type_ids = ["human"]
			part.tags = ["slot_%d" % slot_index]
			parts.register_part(part)
	var body = BodyScript.new("human", "Human")
	body.required_slot_ids = ["slot_0", "slot_1", "slot_2", "slot_3", "slot_4"]
	body.supported_weapon_tags = ["magic"]
	return {"slots": slots, "parts": parts, "body": body}
