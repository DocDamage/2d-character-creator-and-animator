# Unit tests for Phase 3 character schemas, registries, assembly, and conflict repairs.
extends Node

const BodyTypeScript = preload("res://character/definitions/character_body_type_definition.gd")
const SlotScript = preload("res://character/definitions/character_slot_definition.gd")
const PartScript = preload("res://character/definitions/character_part_definition.gd")
const SlotRegistryScript = preload("res://character/registries/character_slot_registry.gd")
const PartRegistryScript = preload("res://character/registries/character_part_registry.gd")
const AssemblyScript = preload("res://character/assembly/character_assembly.gd")


func run_tests() -> int:
	var passes := 0
	passes += test_schemas_and_registries()
	passes += test_assembly_and_conflict_explanations()
	return passes


func test_schemas_and_registries() -> int:
	var fixture = _fixture()
	var parts: Array = fixture.parts.list_parts({"body_type_id": "human", "slot_id": "hair", "query": "crop"})
	var restored := PartScript.new().from_dict(fixture.parts.get_part("hair_crop").to_dict())
	if fixture.slots.validate().is_empty() and fixture.parts.validate(fixture.slots).is_empty() and parts.size() == 1 and restored.part_id == "hair_crop" and restored.palette_channels.has("hair"):
		print("  PASS: CHR-001/CHR-002 part, body, and slot schemas validate and browse")
		return 1
	printerr("  FAIL: CHR schema or registry validation failed")
	return 0


func test_assembly_and_conflict_explanations() -> int:
	var fixture = _fixture()
	var assembly = _assembly(fixture)
	var body_ok: bool = assembly.set_body_type("human").get("success", false)
	var core_ok: bool = assembly.equip_part("core_human").get("success", false)
	var hair_ok: bool = assembly.equip_part("hair_crop").get("success", false)
	var conflict: Dictionary = assembly.equip_part("helmet_closed")
	var explained: Dictionary = assembly.explain_part("helmet_closed")
	var accessory_a: bool = assembly.equip_part("ring_gold").get("success", false)
	var accessory_b: bool = assembly.equip_part("ring_silver").get("success", false)
	var valid: Dictionary = assembly.validate()
	var restored = AssemblyScript.new().from_dict(assembly.to_dict())
	restored.configure(fixture.parts, fixture.slots, [fixture.body])
	if body_ok and core_ok and hair_ok and not conflict.get("success", true) and not explained.get("success", true) and accessory_a and accessory_b and valid.get("success", false) and assembly.get_equipped_part_ids().size() == 4 and restored.validate().get("success", false):
		print("  PASS: CHR-003/CHR-004 assemblies reject conflicts with actionable explanations")
		return 1
	printerr("  FAIL: CHR assembly validation or conflict repair failed: %s" % str(valid))
	return 0


func _assembly(fixture: Dictionary):
	var assembly = AssemblyScript.new("hero", "Hero")
	assembly.configure(fixture.parts, fixture.slots, [fixture.body])
	return assembly


func _fixture() -> Dictionary:
	var slots = SlotRegistryScript.new()
	var torso = SlotScript.new("torso", "Torso")
	torso.required = true
	torso.allowed_part_tags = ["torso"]
	var hair = SlotScript.new("hair", "Hair")
	hair.allowed_part_tags = ["hair", "helmet"]
	var accessory = SlotScript.new("accessory", "Accessory")
	accessory.allow_multiple = true
	accessory.allowed_part_tags = ["accessory"]
	for slot in [torso, hair, accessory]: slots.register_slot(slot)
	var parts = PartRegistryScript.new()
	var core = _part("core_human", "Human Core", "torso", ["torso"])
	var crop = _part("hair_crop", "Crop Hair", "hair", ["hair"])
	crop.excluded_tags = ["helmet"]
	crop.palette_channels = {"hair": {"default": "#663300"}}
	var helmet = _part("helmet_closed", "Closed Helmet", "accessory", ["accessory", "helmet"])
	var gold = _part("ring_gold", "Gold Ring", "accessory", ["accessory"])
	var silver = _part("ring_silver", "Silver Ring", "accessory", ["accessory"])
	for part in [core, crop, helmet, gold, silver]: parts.register_part(part)
	var body = BodyTypeScript.new("human", "Human")
	body.required_slot_ids = ["torso"]
	return {"slots": slots, "parts": parts, "body": body}


func _part(part_id: String, name: String, slot_id: String, tags: Array):
	var part = PartScript.new(part_id, name, slot_id)
	part.asset_id = "asset_" + part_id
	part.supported_body_type_ids = ["human"]
	part.tags = PackedStringArray(tags)
	return part
