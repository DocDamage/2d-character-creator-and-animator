# Integration tests for Phase 5 linked-project refresh, recovery, packaging, and multi-character preview.
extends Node

const LinkedProjectsScript = preload("res://linked_projects/linked_project_service.gd")


func run_tests() -> int:
	var service = LinkedProjectsScript.new()
	var initial := {"rig_shared": {"asset_id": "rig_shared", "resource_type": "rig", "data": {"bones": 20}}, "hero": {"asset_id": "hero", "resource_type": "character", "data": {"rig": "rig_shared", "palette": "blue"}}, "sword": {"asset_id": "sword", "resource_type": "accessory", "data": {"socket": "hand_r"}}}
	var linked: bool = service.link_project("library", "shared_library", "res://shared", initial, 1)
	var override_ok: bool = service.set_local_override("library", "hero", {"data": {"palette": "red"}})
	var incoming := initial.duplicate(true)
	incoming["hero"] = {"asset_id": "hero", "resource_type": "character", "data": {"rig": "rig_shared", "palette": "green"}}
	var refresh: Dictionary = service.refresh_link("library", incoming, 2)
	var conflict_ok: bool = refresh.get("conflicts", []).size() == 1 and service.resolve_conflict("library", "hero", "keep_local")
	var packaged: Dictionary = service.package_dependencies([{"link_id": "library", "asset_id": "hero"}, {"link_id": "library", "asset_id": "rig_shared"}, {"link_id": "library", "asset_id": "sword"}])
	var preview: Dictionary = service.preview_multi_character([{"link_id": "library", "asset_id": "hero", "position": [0.0, 0.0]}, {"link_id": "library", "asset_id": "hero", "position": [120.0, 0.0], "facing": "left"}])
	var broken: Dictionary = service.refresh_link("library", {"hero": incoming["hero"]}, 3)
	var restored: Dictionary = service.refresh_link("library", incoming, 4)
	var round_trip = LinkedProjectsScript.new().from_dict(service.to_dict())
	if linked and override_ok and conflict_ok and service.get_resource("library", "hero").get("data", {}).get("palette") == "red" and packaged.get("valid", false) and packaged.get("assets", []).size() == 3 and preview.get("valid", false) and preview.get("characters", []).size() == 2 and broken.get("missing", []).size() == 2 and restored.get("missing", []).is_empty() and round_trip.validate().is_empty():
		print("  PASS: LNK-001 through LNK-008 shared assets, overrides, conflicts, recovery, packaging, and multi-character preview")
		return 1
	printerr("  FAIL: linked-project workflow did not refresh or recover safely")
	return 0
