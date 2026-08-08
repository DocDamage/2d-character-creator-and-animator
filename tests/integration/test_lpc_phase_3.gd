# TestLpcPhase3 -- Acceptance for copy-on-edit pixels, atomic commands, cel timing, persistence, and immutable sources.
class_name TestLpcPhase3
extends Node

const FixtureFactoryScript = preload("res://tests/lpc_phase_fixture_factory.gd")
const CatalogBuilderScript = preload("res://lpc/catalog/lpc_catalog_builder.gd")
const ProjectStoreScript = preload("res://lpc/project/lpc_project_store.gd")
const CreatorModelScript = preload("res://lpc/creator/lpc_creator_model.gd")
const CanvasModelScript = preload("res://lpc/pixels/lpc_pixel_canvas_model.gd")
const DerivativeStoreScript = preload("res://lpc/pixels/lpc_derivative_store.gd")
const CelTimelineScript = preload("res://lpc/cels/lpc_cel_timeline.gd")
const PixelPanelScript = preload("res://lpc/ui/lpc_pixel_editor_panel.gd")


func run_all_tests() -> Dictionary:
	var result := _exercise_pixel_cel_workflow()
	if bool(result.get("success", false)):
		print("  PASS: LPC phase 3 creates immutable derivatives, atomic pixel edits, cels, onion state, and lossless persistence")
		return {"passed": 1, "failed": 0, "errors": []}
	printerr("  FAIL: LPC phase 3 workflow failed: %s" % str(result.get("errors", [])))
	return {"passed": 0, "failed": 1, "errors": result.get("errors", [])}


func _exercise_pixel_cel_workflow() -> Dictionary:
	var root := "user://lpc_phase3_" + IDService.generate_short("pixel")
	var fixture := FixtureFactoryScript.create(root); var errors: Array[String] = []
	for error in fixture.get("errors", []): errors.append(str(error))
	if not bool(fixture.get("success", false)): return {"success": false, "errors": errors}
	var built := CatalogBuilderScript.build(str(fixture.get("source_root", "")))
	if not bool(built.get("success", false)): errors.append_array(built.get("errors", []))
	var catalog: Dictionary = built.get("catalog", {})
	var project_path := root.path_join("PixelRanger.chrproj")
	var created := ProjectStoreScript.create_new(project_path, {"catalog": catalog, "label": "Pixel Ranger", "body_family_id": "human", "policy_id": "full_source"}) if errors.is_empty() else {}
	var opened := ProjectStoreScript.open(project_path, false) if bool(created.get("success", false)) else {}
	var creator = CreatorModelScript.new()
	var bound := creator.bind_context(catalog, opened.get("profile", {}), opened.get("manifest", {}), project_path) if bool(opened.get("success", false)) else {}
	var selected := creator.select_asset("body_human") if bool(bound.get("success", false)) else {}
	var saved_creator := creator.save() if bool(selected.get("success", false)) else {}
	var pixel = CanvasModelScript.new()
	var loaded := pixel.open_native_frame(catalog, creator.profile, "base:body_human") if bool(saved_creator.get("success", false)) else {}
	var source_path := str((fixture.get("files", {}) as Dictionary).get("body_human", "")); var source_hash := FixtureFactoryScript.hash(source_path)
	pixel.set_exact_palette([Color("ff0000"), Color("00ff00"), Color(0, 0, 0, 0)])
	var began := pixel.begin_stroke("Two-pixel pencil stroke") if bool(loaded.get("success", false)) else false
	var painted_one := pixel.paint_pixel(Vector2i(1, 1), Color("ff0000")) if began else false
	var painted_two := pixel.paint_pixel(Vector2i(2, 1), Color("ff0000")) if began else false
	var stroked := pixel.end_stroke() if began else false
	var stroke_command_count := pixel.command_count()
	var after_stroke_hash := DerivativeStoreScript.image_hash(pixel.image) if stroked else ""
	var undone := pixel.undo() if stroked else false
	var redone := pixel.redo() if undone else false
	var selected_pixels := pixel.select_contiguous(Vector2i(1, 1)) if redone else 0
	var copied := pixel.copy_selection() if selected_pixels > 0 else {}
	var pasted := pixel.paste(Vector2i(6, 1)) if not copied.is_empty() else false
	var first_commit := pixel.commit_to_profile(creator.profile, {"target_id": "base:body_human", "frame": 2, "kind": "pixel_edit", "reference_layers": ["base:body_human"]}) if pasted else {}
	var profile_after_first: Dictionary = first_commit.get("profile", {})
	var began_second := pixel.begin_stroke("Second cel stroke") if bool(first_commit.get("success", false)) else false
	if began_second: pixel.paint_pixel(Vector2i(10, 10), Color("00ff00")); pixel.end_stroke()
	var second_commit := pixel.commit_to_profile(profile_after_first, {"target_id": "base:body_human", "frame": 4, "kind": "gap_patch"}) if began_second else {}
	var profile: Dictionary = second_commit.get("profile", {})
	var derivative: Dictionary = second_commit.get("derivative", {})
	var loaded_derivative := DerivativeStoreScript.load_image(derivative) if not derivative.is_empty() else null
	var onion: Array = CelTimelineScript.onion_layers(profile, "base:body_human", 3, 1, 1) if not profile.is_empty() else []
	var blobs_before := DerivativeStoreScript.blob_count(profile)
	var autosaved := ProjectStoreScript.autosave(project_path, creator.manifest, profile) if not profile.is_empty() else {}
	var blobs_after := DerivativeStoreScript.blob_count(profile)
	var saved := ProjectStoreScript.save(project_path, creator.manifest, profile) if bool(autosaved.get("success", false)) else {}
	var reopened := ProjectStoreScript.open(project_path, false) if bool(saved.get("success", false)) else {}
	var exported_path := root.path_join("pixel_roundtrip.png")
	var exported := pixel.export_png(exported_path) if pixel.image != null else false
	var reloaded = CanvasModelScript.new(); var imported := reloaded.import_png(exported_path) if exported else false
	var panel = PixelPanelScript.new(); add_child(panel); var panel_bound := panel.bind_context(catalog, profile, creator.manifest, project_path) if not profile.is_empty() else {}; panel.queue_free()
	if not bool(created.get("success", false)) or not bool(opened.get("success", false)): errors.append("Could not create and reopen the LPC pixel-edit project.")
	if not bool(selected.get("success", false)) or not bool(loaded.get("success", false)): errors.append("A selected native source frame could not be opened for editing.")
	if not began or not painted_one or not painted_two or not stroked or stroke_command_count != 1: errors.append("A multi-pixel pencil gesture was not recorded as one atomic command: %s" % str({"loaded": loaded, "began": began, "painted_one": painted_one, "painted_two": painted_two, "stroked": stroked, "commands": stroke_command_count}))
	if not undone or not redone or DerivativeStoreScript.image_hash(pixel.image) == "" or after_stroke_hash == "": errors.append("Pixel undo/redo did not restore valid image state.")
	if selected_pixels != 2 or not pasted: errors.append("Contiguous selection and copy/paste did not preserve the two-pixel edit.")
	if not bool(first_commit.get("success", false)) or not bool(second_commit.get("success", false)) or profile.get("derivative_references", []).size() != 2: errors.append("Copy-on-edit derivatives were not stored with durable project references.")
	if loaded_derivative == null or loaded_derivative.is_empty() or loaded_derivative.get_pixel(10, 10).to_html(true).to_lower() != "00ff00ff": errors.append("Stored derivative PNG was not losslessly reloaded.")
	if onion.size() != 2 or not CelTimelineScript.validate(profile).is_empty(): errors.append("Timed cels and onion-skin references are incomplete or invalid.")
	if not bool(autosaved.get("success", false)) or blobs_before != blobs_after: errors.append("Autosave unexpectedly created a new derivative blob.")
	if not bool(saved.get("success", false)) or not bool(reopened.get("success", false)) or (reopened.get("profile", {}).get("cels", []) as Array).size() != 2: errors.append("Pixel cels did not survive project save/reopen.")
	if not exported or not imported or DerivativeStoreScript.image_hash(reloaded.image) != DerivativeStoreScript.image_hash(pixel.image): errors.append("Pixel PNG import/export is not lossless.")
	if not bool(panel_bound.get("success", false)): errors.append("The reachable Pixel & Cels workspace could not bind the project context.")
	if FixtureFactoryScript.hash(source_path) != source_hash: errors.append("Pixel editing changed immutable LPC source art.")
	return {"success": errors.is_empty(), "errors": errors}
