# SchemaMigration — Migration pipeline for project manifest schema updates
# Path: core/migrations/schema_migration.gd
class_name SchemaMigration
extends RefCounted

const CURRENT_VERSION := "1.0.0"


static func can_migrate(from_version: String) -> bool:
	return from_version != CURRENT_VERSION


static func migrate(data: Dictionary, from_version: String, target_version: String = CURRENT_VERSION) -> Dictionary:
	if from_version == target_version:
		return data.duplicate(true)

	var migrated := data.duplicate(true)

	if _compare_versions(from_version, "0.9.0") < 0:
		migrated = _migrate_0_1_0_to_0_9_0(migrated)

	if _compare_versions(from_version, "1.0.0") < 0:
		migrated = _migrate_0_9_0_to_1_0_0(migrated)

	migrated["schema_version"] = target_version
	return migrated


static func _migrate_0_1_0_to_0_9_0(data: Dictionary) -> Dictionary:
	var copy := data.duplicate(true)
	if not copy.has("objects") or typeof(copy["objects"]) != TYPE_DICTIONARY:
		copy["objects"] = {}
	var objs: Dictionary = copy["objects"]
	for category in ["characters", "rigs", "animations", "weapons", "assets", "palettes"]:
		if not objs.has(category) or typeof(objs[category]) != TYPE_DICTIONARY:
			objs[category] = {}
	return copy


static func _migrate_0_9_0_to_1_0_0(data: Dictionary) -> Dictionary:
	var copy := data.duplicate(true)
	if not copy.has("objects") or typeof(copy["objects"]) != TYPE_DICTIONARY:
		copy["objects"] = {}
	var objs: Dictionary = copy["objects"]
	for category in ["characters", "rigs", "animations", "weapons", "assets"]:
		if not objs.has(category) or typeof(objs[category]) != TYPE_DICTIONARY:
			objs[category] = {}
	if not copy.has("settings") or typeof(copy["settings"]) != TYPE_DICTIONARY:
		copy["settings"] = {
			"default_facing_directions": 8,
			"default_fps": 30,
			"pixel_mode": false
		}
	if not copy.has("metadata") or typeof(copy["metadata"]) != TYPE_DICTIONARY:
		copy["metadata"] = {
			"author": "",
			"description": "",
			"generator": "Modular 2D Character Creator and Animation Studio"
		}
	return copy


static func _compare_versions(v1: String, v2: String) -> int:
	var p1 := v1.split(".")
	var p2 := v2.split(".")
	for i in range(mini(p1.size(), p2.size())):
		var n1 := p1[i].to_int()
		var n2 := p2[i].to_int()
		if n1 != n2:
			return 1 if n1 > n2 else -1
	return 0
