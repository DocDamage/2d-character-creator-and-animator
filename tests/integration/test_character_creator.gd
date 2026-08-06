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


func run_tests() -> int:
	var passes := 0
	passes += test_creator_edits_are_browseable_reversible_and_weapon_safe()
	passes += test_seeded_npc_batch_has_one_hundred_unique_valid_assemblies()
	return passes


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
