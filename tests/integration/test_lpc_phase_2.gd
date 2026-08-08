# TestLpcPhase2 -- End-to-end acceptance for focused creator selections, native clips, save/reopen, and PNG export.
class_name TestLpcPhase2
extends Node

const FixtureFactoryScript = preload("res://tests/lpc_phase_fixture_factory.gd")
const CatalogBuilderScript = preload("res://lpc/catalog/lpc_catalog_builder.gd")
const ProjectStoreScript = preload("res://lpc/project/lpc_project_store.gd")
const CreatorModelScript = preload("res://lpc/creator/lpc_creator_model.gd")


func run_all_tests() -> Dictionary:
	var test := _exercise_creator_workflow()
	if bool(test.get("success", false)):
		print("  PASS: LPC phase 2 assembles, resolves, previews, saves, reopens, and exports native clips")
		return {"passed": 1, "failed": 0, "errors": []}
	printerr("  FAIL: LPC phase 2 workflow failed: %s" % str(test.get("errors", [])))
	return {"passed": 0, "failed": 1, "errors": test.get("errors", [])}


func _exercise_creator_workflow() -> Dictionary:
	var root := "user://lpc_phase2_" + IDService.generate_short("native")
	var fixture := FixtureFactoryScript.create(root)
	var errors: Array[String] = []
	for error in fixture.get("errors", []): errors.append(str(error))
	if not bool(fixture.get("success", false)): return {"success": false, "errors": errors}
	var source_root := str(fixture.get("source_root", ""))
	var built := CatalogBuilderScript.build(source_root)
	if not bool(built.get("success", false)): errors.append_array(built.get("errors", []))
	var catalog: Dictionary = built.get("catalog", {})
	var project_path := root.path_join("Ranger.chrproj")
	var created := ProjectStoreScript.create_new(project_path, {"catalog": catalog, "label": "Ranger", "body_family_id": "human", "policy_id": "drm_friendly"}) if errors.is_empty() else {}
	var opened := ProjectStoreScript.open(project_path, false) if bool(created.get("success", false)) else {}
	var model = CreatorModelScript.new()
	var bound := model.bind_context(catalog, opened.get("profile", {}), opened.get("manifest", {}), project_path) if bool(opened.get("success", false)) else {}
	var body := model.select_asset("body_human") if bool(bound.get("success", false)) else {}
	var shirt := model.select_asset("shirt_blue") if bool(body.get("success", false)) else {}
	var cape := model.select_asset("cape_partial") if bool(shirt.get("success", false)) else {}
	var unresolved := model.preview("walk", "down", 0.0) if bool(cape.get("success", false)) else {}
	var hide := model.set_missing_animation_action("back:cape_partial", "walk", "hide_for_clip") if not bool(unresolved.get("success", false)) else {}
	var preview := model.preview("walk", "down", 0.2) if bool(hide.get("success", false)) else {}
	var exported := model.export_native("walk", "down", root.path_join("native_export"), {"fps": 10.0}) if bool(preview.get("success", false)) else {}
	var saved := model.save() if bool(exported.get("success", false)) else {}
	var reopened := ProjectStoreScript.open(project_path, false) if bool(saved.get("success", false)) else {}
	var restored = CreatorModelScript.new()
	var rebound := restored.bind_context(catalog, reopened.get("profile", {}), reopened.get("manifest", {}), project_path) if bool(reopened.get("success", false)) else {}
	var replay := restored.preview("walk", "down", 0.2) if bool(rebound.get("success", false)) else {}
	var body_path := str((fixture.get("files", {}) as Dictionary).get("body_human", ""))
	if not bool(created.get("success", false)): errors.append_array(created.get("errors", ["Could not create an LPC project."]))
	if not bool(opened.get("success", false)): errors.append_array(opened.get("errors", ["Could not reopen the new LPC project."]))
	if not bool(bound.get("success", false)) or not bool(body.get("success", false)) or not bool(shirt.get("success", false)) or not bool(cape.get("success", false)): errors.append("The creator could not select compatible catalog layers.")
	if bool(unresolved.get("success", true)) or (unresolved.get("conflicts", []) as Array).is_empty(): errors.append("A missing native animation was not surfaced as an explicit conflict.")
	if not bool(hide.get("success", false)): errors.append("The explicit hide-for-clip resolution was rejected.")
	if not bool(preview.get("success", false)) or preview.get("image", null) == null or (preview.image as Image).get_size() != Vector2i(64, 64): errors.append("Verified native preview did not produce a logical LPC frame.")
	if not bool(exported.get("success", false)) or int(exported.get("frame_count", 0)) != 9 or not FileAccess.file_exists(str(exported.get("manifest", ""))): errors.append("Native PNG export did not produce the exact walk cycle and manifest.")
	if not bool(saved.get("success", false)) or not bool(reopened.get("success", false)) or (reopened.get("profile", {}).get("selections", []) as Array).size() != 3: errors.append("Creator selections did not survive save/reopen.")
	if not bool(replay.get("success", false)) or str(replay.get("output_hash", "")) != str(preview.get("output_hash", "")): errors.append("Reopened native preview differs from the saved render snapshot output.")
	if FixtureFactoryScript.hash(body_path) != str((((catalog.get("assets", {}) as Dictionary).get("body_human", {}) as Dictionary).get("source_sha256", ""))): errors.append("Creator/export workflow changed immutable source art.")
	return {"success": errors.is_empty(), "errors": errors}
