# Integration coverage for the release-hardening pass.  All fixtures are
# artist-imported pixels written into user:// test folders; no generated art,
# installers, network calls, or publishing credentials are involved.
extends Node

const AssetRegistryScript = preload("res://core/assets/asset_registry.gd")
const ImageImporterScript = preload("res://core/assets/image_importer.gd")
const ImportPreflightScript = preload("res://core/assets/asset_import_preflight.gd")
const MissingFileRepairScript = preload("res://core/assets/missing_file_repair.gd")
const FactoryScript = preload("res://character/authoring/character_project_factory.gd")
const SessionScript = preload("res://character/authoring/character_project_session.gd")
const SupportBundleExporterScript = preload("res://quality/recovery/support_bundle_exporter.gd")
const ProjectScaleAdvisorScript = preload("res://quality/performance/project_scale_advisor.gd")
const LargeProjectStressSuiteScript = preload("res://quality/performance/large_project_stress_suite.gd")
const ReleaseReadinessScript = preload("res://release/release_readiness.gd")
const ReleaseBuilderScript = preload("res://release/release_builder.gd")
const UpdateServiceScript = preload("res://app/bootstrap/update_service.gd")


func run_tests() -> Dictionary:
	var root := "user://release_hardening_tests/" + IDService.generate_short("release")
	var visible_path := root.path_join("body_visible.png")
	var transparent_path := root.path_join("body_empty.png")
	var project_path := root.path_join("hardening.chrproj")
	var checks := {}
	if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(root)) != OK:
		return {"passed": 0, "failed": 1, "errors": ["Could not create release-hardening fixture folder."]}
	checks["fixtures"] = _write_pixel_png(visible_path, Color(0.25, 0.75, 0.9, 1.0)) and _write_pixel_png(transparent_path, Color(0.0, 0.0, 0.0, 0.0))
	var registry = AssetRegistryScript.new()
	var imported: Dictionary = ImageImporterScript.import_image(visible_path, registry)
	var preflight: Dictionary = ImportPreflightScript.inspect_path(visible_path, registry, {"canvas": {"width": 16, "height": 16}})
	var transparent: Dictionary = ImportPreflightScript.inspect_path(transparent_path, registry)
	var audit_before: Dictionary = ImportPreflightScript.audit_registry(registry, {"canvas": {"width": 16, "height": 16}})
	var inspection: Dictionary = ImageImporterScript.inspect_image(visible_path)
	var missing_asset: Dictionary = registry.register_asset(root.path_join("missing_copy.png"), AssetRegistry.CATEGORY_SOURCE_ART, {"checksum": str(inspection.get("checksum", ""))})
	var repair_plan: Dictionary = MissingFileRepairScript.plan_deterministic_repairs(registry, [visible_path], [AssetRegistry.CATEGORY_SOURCE_ART])
	checks["import preflight"] = bool(preflight.get("valid", false)) and not (preflight.get("duplicate_asset_ids", []) as Array).is_empty() and not bool(transparent.get("valid", true)) and int(audit_before.get("warning_count", 0)) > 0
	if not bool(checks["import preflight"]): print("  INFO import-preflight debug: ", [imported, preflight, transparent, audit_before])
	checks["deterministic repair plan"] = (repair_plan.get("repairs", []) as Array).any(func(item): return str((item as Dictionary).get("asset_id", "")) == str(missing_asset.get("asset_id", ""))) and (repair_plan.get("ambiguous", []) as Array).is_empty()

	var session = SessionScript.new()
	add_child(session)
	var session_ready := SerializationService.save_project(FactoryScript.create_manifest("Release Hardening", "blank"), project_path) and bool(session.open_project(project_path).get("success", false))
	var duplicate_import: Dictionary = session.import_files_by_slot([visible_path, visible_path], "body") if session_ready else {}
	var imported_part: Dictionary = (duplicate_import.get("imported", [])[0] as Dictionary) if not (duplicate_import.get("imported", []) as Array).is_empty() else {}
	var provenance_saved := false
	if bool(imported_part.get("success", false)):
		provenance_saved = session.set_asset_provenance(str(imported_part.get("asset_id", "")), {"author": "Fixture Artist", "license": "Test License", "source_reference": "fixture"})
	var audit_after: Dictionary = session.get_import_preflight_report() if session_ready else {}
	var scale: Dictionary = session.get_project_scale_report() if session_ready else {}
	var synthetic_scale: Dictionary = ProjectScaleAdvisorScript.analyze_synthetic({"layers": 121, "tracks": 301, "keys": 10001, "appearance_sets": 65, "review_frames": 2501})
	var stress: Dictionary = LargeProjectStressSuiteScript.new().run(100, 20, 50)
	var support: Dictionary = SupportBundleExporterScript.new().create_bundle(session, root) if session_ready else {}
	checks["provenance and scale"] = session_ready and (duplicate_import.get("imported", []) as Array).size() == 1 and bool(imported_part.get("success", false)) and provenance_saved and bool(scale.get("success", false)) and int((scale.get("counts", {}) as Dictionary).get("assets", 0)) >= 1 and int(audit_after.get("warning_count", 0)) < int(audit_before.get("warning_count", 0)) + 2 and not (synthetic_scale.get("issues", []) as Array).is_empty() and not ((stress.get("scale", {}) as Dictionary).get("issues", []) as Array).is_empty()
	checks["local support bundle"] = bool(support.get("success", false)) and not bool(support.get("contains_artwork", true)) and not bool(support.get("uploaded", true)) and FileAccess.file_exists(str(support.get("zip", "")))

	var readiness: Dictionary = ReleaseReadinessScript.new().validate()
	var builder := ReleaseBuilderScript.new()
	var release_preflight: Dictionary = builder.preflight()
	var identity: Dictionary = builder.get_release_identity()
	var missing_artifact: Dictionary = builder.verify_windows_artifacts("release/windows/not_a_real_build.exe", false)
	var unsafe_manifest: Dictionary = builder.write_update_manifest("../unsafe.json", "https://example.invalid/download", "unsafe")
	checks["release packaging"] = bool(readiness.get("valid", false)) and bool(release_preflight.get("ready", false)) and str(identity.get("version", "")) == str(ProjectSettings.get_setting("application/config/version", "")) and FileAccess.file_exists("res://release/windows/PaperQuestCharacterStudio.nsi") and not bool(missing_artifact.get("success", true)) and not bool(unsafe_manifest.get("success", true))

	var updates = UpdateServiceScript.new()
	add_child(updates)
	updates.configure_feed("http://insecure.example/manifest.json", "stable")
	var insecure_update: Dictionary = updates.check_for_updates()
	updates.configure_feed("", "stable")
	var bundled_update: Dictionary = updates.check_bundled_manifest()
	checks["secure update behavior"] = not bool(insecure_update.get("success", true)) and not bool(bundled_update.get("configured", true)) and "no public update feed" in str(bundled_update.get("message", "")).to_lower()
	updates.free()
	if is_instance_valid(session): session.free()
	registry.free()
	_cleanup(root)
	if _all_true(checks):
		print("  PASS: Release hardening preflight, provenance, deterministic repair, scale guidance, local support, packaging, and secure update behavior")
		return {"passed": 1, "failed": 0, "errors": []}
	return {"passed": 0, "failed": 1, "errors": ["Release-hardening checks failed: " + str(checks)]}


func _write_pixel_png(path: String, color: Color) -> bool:
	var image := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	image.fill(color)
	return image.save_png(ProjectSettings.globalize_path(path)) == OK


func _all_true(checks: Dictionary) -> bool:
	for key in checks:
		if not bool(checks[key]): return false
	return true


func _cleanup(root: String) -> void:
	var absolute := ProjectSettings.globalize_path(root)
	if DirAccess.dir_exists_absolute(absolute): _delete_tree(absolute)


func _delete_tree(path: String) -> void:
	var directory := DirAccess.open(path)
	if directory == null: return
	directory.list_dir_begin()
	var entry := directory.get_next()
	while not entry.is_empty():
		if entry != "." and entry != "..":
			var child := path.path_join(entry)
			if directory.current_is_dir(): _delete_tree(child)
			else: DirAccess.remove_absolute(child)
		entry = directory.get_next()
	directory.list_dir_end()
	DirAccess.remove_absolute(path)
