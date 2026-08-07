# Test Runner — Executes test suite in Godot engine runtime environment with autoloads active
extends Node
const TestStartupScript = preload("res://tests/unit/test_startup.gd")
const TestDockLayoutScript = preload("res://tests/unit/test_dock_layout.gd")
const TestWorkspaceManagerScript = preload("res://tests/unit/test_workspace_manager.gd")
const TestCommandPaletteScript = preload("res://tests/unit/test_command_palette.gd")
const TestDirtyStateScript = preload("res://tests/unit/test_dirty_state.gd")
const TestDiagnosticsDrawerScript = preload("res://tests/unit/test_diagnostics_drawer.gd")
const TestThemeDPIScript = preload("res://tests/unit/test_theme_dpi.gd")
const TestFocusFrameworkScript = preload("res://tests/unit/test_focus_framework.gd")
const TestRecentProjectsScript = preload("res://tests/unit/test_recent_projects.gd")
const TestDocumentSchemaScript = preload("res://tests/unit/test_document_schema.gd")
const TestIDServiceScript = preload("res://tests/unit/test_id_service.gd")
const TestSerializationScript = preload("res://tests/unit/test_serialization.gd")
const TestTransactionalSaveScript = preload("res://tests/integration/test_transactional_save.gd")
const TestProjectLoadScript = preload("res://tests/integration/test_project_load.gd")
const TestBackupsScript = preload("res://tests/integration/test_backups.gd")
const TestRecoveryScript = preload("res://tests/integration/test_recovery.gd")
const TestMigrationsScript = preload("res://tests/integration/test_migrations.gd")
const TestCorruptRecoveryScript = preload("res://tests/integration/test_corrupt_recovery.gd")
const TestCleanConsumerExportScript = preload("res://tests/integration/test_clean_consumer_export.gd")
const TestExportArtifactValidationScript = preload("res://tests/integration/test_export_artifact_validation.gd")
const TestFacingGridAcceptanceScript = preload("res://tests/integration/test_facing_grid_acceptance.gd")
const TestWeaponMetadataAcceptanceScript = preload("res://tests/integration/test_weapon_metadata_acceptance.gd")
const TestFacingDirectionEditorScript = preload("res://tests/integration/test_facing_direction_editor.gd")
const TestFacingFilenamePlacementScript = preload("res://tests/integration/test_facing_filename_placement.gd")
const TestCloneScript = preload("res://tests/unit/test_clone.gd")
const TestAssetLibraryScript = preload("res://tests/unit/test_asset_library.gd")
const TestCanvasCommandScript = preload("res://tests/unit/test_canvas_command.gd")
const TestRiggingScript = preload("res://tests/unit/test_rigging.gd")
const TestConstraintsIKScript = preload("res://tests/unit/test_constraints_ik.gd")
const TestAnimationTimelineScript = preload("res://tests/unit/test_animation_timeline.gd")
const TestCurvesOnionScript = preload("res://tests/unit/test_curves_onion.gd")
const TestMeshDeformationScript = preload("res://tests/unit/test_mesh_deformation.gd")
const TestWeaponGameplayScript = preload("res://tests/unit/test_weapon_gameplay.gd")
const TestFacingExportRuntimeScript = preload("res://tests/unit/test_facing_export_runtime.gd")
const TestPoseAuthoringScript = preload("res://tests/integration/test_pose_authoring.gd")
const TestRetargetingScript = preload("res://tests/integration/test_retargeting.gd")
const TestAuthoringCompletionScript = preload("res://tests/integration/test_authoring_completion.gd")
const TestReleaseHardeningScript = preload("res://tests/integration/test_release_hardening.gd")
const TestProductionDeliveryScript = preload("res://tests/integration/test_production_delivery.gd")
const TestLpcPhase01Script = preload("res://tests/integration/test_lpc_phase_0_1.gd")
const TestLpcPhase2Script = preload("res://tests/integration/test_lpc_phase_2.gd")
const TestLpcPhase3Script = preload("res://tests/integration/test_lpc_phase_3.gd")
func _ready() -> void:
	print("=== Running Automated Test Suite ===")
	print("")
	var pass_count := 0
	var fail_count := 0
	# 1. Test baseline valid fixture loading
	print("[TEST 1] Baseline valid fixture loading...")
	var baseline_data := SerializationService.load_project("res://tests/fixtures/baseline/valid_project.chrproj")
	if baseline_data.is_empty():
		printerr("  FAIL: Baseline fixture returned empty dictionary.")
		fail_count += 1
	else:
		var errors := SerializationService.validate_project(baseline_data)
		if not errors.is_empty():
			printerr("  FAIL: Baseline validation errors: " + str(errors))
			fail_count += 1
		else:
			print("  PASS: Baseline fixture loaded and validated successfully.")
			pass_count += 1
	# 2. Test malformed corrupt fixture handling
	print("[TEST 2] Malformed corrupt fixture handling...")
	var corrupt_data := SerializationService.load_project("res://tests/fixtures/malformed/corrupt_project.chrproj")
	if corrupt_data.is_empty():
		print("  PASS: Malformed fixture handled safely without crash.")
		pass_count += 1
	else:
		printerr("  FAIL: Corrupt fixture loaded unexpected data.")
		fail_count += 1

	# 3. Test IDService generation & registration
	print("[TEST 3] IDService UUID & registration...")
	var uuid := IDService.generate_uuid_v4()
	if uuid.length() == 36 and IDService.register(uuid):
		print("  PASS: IDService generated and registered valid UUID: %s" % uuid)
		pass_count += 1
	else:
		printerr("  FAIL: IDService UUID generation/registration failed.")
		fail_count += 1

	# 4. Test CommandService undo/redo
	print("[TEST 4] CommandService stack...")
	CommandService.clear_history()
	if CommandService.can_undo() == false and CommandService.can_redo() == false:
		print("  PASS: CommandService initialized clean stack.")
		pass_count += 1
	else:
		printerr("  FAIL: CommandService stack state invalid.")
		fail_count += 1

	# 5. Run Startup Unit Tests
	var startup_test_runner := TestStartupScript.new()
	add_child(startup_test_runner)
	var startup_res: Dictionary = startup_test_runner.run_tests()
	pass_count += startup_res.get("passed", 0) as int
	fail_count += startup_res.get("failed", 0) as int
	for err in startup_res.get("errors", []):
		printerr("  FAIL: " + str(err))
	startup_test_runner.queue_free()

	# 6. Run Dock Layout Unit Tests
	var dock_test_runner := TestDockLayoutScript.new()
	add_child(dock_test_runner)
	var dock_res: Dictionary = dock_test_runner.run_tests()
	pass_count += dock_res.get("passed", 0) as int
	fail_count += dock_res.get("failed", 0) as int
	for err in dock_res.get("errors", []):
		printerr("  FAIL: " + str(err))
	dock_test_runner.queue_free()

	# 7. Run Workspace Manager Unit Tests
	print("[TEST 7] Workspace Manager workflows & state preservation...")
	var ws_test_runner := TestWorkspaceManagerScript.new()
	var ws_res: Dictionary = ws_test_runner.run_all_tests()
	pass_count += ws_res.get("passes", 0) as int
	fail_count += ws_res.get("fails", 0) as int

	# 8. Run Command Palette Unit Tests
	var cmd_test_runner := TestCommandPaletteScript.new()
	add_child(cmd_test_runner)
	var cmd_passed: bool = cmd_test_runner.run_all_tests()
	if cmd_passed:
		pass_count += 1
	else:
		fail_count += 1
	cmd_test_runner.queue_free()

	# 9. Run Dirty State Unit Tests
	var dirty_test_runner := TestDirtyStateScript.new()
	add_child(dirty_test_runner)
	var dirty_res: Dictionary = dirty_test_runner.run_all()
	pass_count += dirty_res.get("pass", 0) as int
	fail_count += dirty_res.get("fail", 0) as int
	dirty_test_runner.queue_free()

	# 10. Run Diagnostics Drawer Unit Tests
	var diag_test_runner := TestDiagnosticsDrawerScript.new()
	add_child(diag_test_runner)
	var diag_res: Dictionary = diag_test_runner.run_all()
	pass_count += diag_res.get("pass", 0) as int
	fail_count += diag_res.get("fail", 0) as int
	diag_test_runner.queue_free()

	# 11. Run Theme & DPI Scaling Unit Tests
	var theme_dpi_test_runner := TestThemeDPIScript.new()
	add_child(theme_dpi_test_runner)
	var theme_dpi_passed: bool = theme_dpi_test_runner.run_all_tests()
	pass_count += theme_dpi_test_runner.get("_pass_count") as int
	fail_count += theme_dpi_test_runner.get("_fail_count") as int
	theme_dpi_test_runner.queue_free()

	# 12. Run Focus Framework Unit Tests
	var focus_test_runner := TestFocusFrameworkScript.new()
	add_child(focus_test_runner)
	var focus_passed: bool = focus_test_runner.run_all_tests()
	pass_count += focus_test_runner.get("_pass_count") as int
	fail_count += focus_test_runner.get("_fail_count") as int
	focus_test_runner.queue_free()

	# 13. Run Recent Projects Unit Tests
	var recent_test_runner := TestRecentProjectsScript.new()
	add_child(recent_test_runner)
	var recent_res: Dictionary = recent_test_runner.run_tests()
	pass_count += recent_res.get("passed", 0) as int
	fail_count += recent_res.get("failed", 0) as int
	for err in recent_res.get("errors", []):
		printerr("  FAIL: " + str(err))
	recent_test_runner.queue_free()

	# 14. Run Document Schema Unit Tests
	var r14 := _exec_sub(TestDocumentSchemaScript.new(), pass_count, fail_count)
	pass_count = r14[0]; fail_count = r14[1]

	# 15. Run IDService Unit Tests
	var r15 := _exec_sub(TestIDServiceScript.new(), pass_count, fail_count)
	pass_count = r15[0]; fail_count = r15[1]

	# 16. Run Serialization Determinism Unit Tests
	var r16 := _exec_sub(TestSerializationScript.new(), pass_count, fail_count)
	pass_count = r16[0]; fail_count = r16[1]

	# 17. Run Transactional Save Integration Tests
	var r17 := _exec_sub(TestTransactionalSaveScript.new(), pass_count, fail_count)
	pass_count = r17[0]; fail_count = r17[1]

	# 18. Run Project Load & Diagnostics Integration Tests
	var r18 := _exec_sub(TestProjectLoadScript.new(), pass_count, fail_count)
	pass_count = r18[0]; fail_count = r18[1]

	# 19. Run Rolling Backups Integration Tests (REQ-DOC-006)
	var r19 := _exec_sub(TestBackupsScript.new(), pass_count, fail_count)
	pass_count = r19[0]; fail_count = r19[1]

	# 20. Run Recovery Journal & Autosave Integration Tests (REQ-DOC-007)
	var r20 := _exec_sub(TestRecoveryScript.new(), pass_count, fail_count)
	pass_count = r20[0]; fail_count = r20[1]

	# 21. Run Schema Migrations Integration Tests (REQ-DOC-008)
	var r21 := _exec_sub(TestMigrationsScript.new(), pass_count, fail_count)
	pass_count = r21[0]; fail_count = r21[1]

	# 22. Run Corrupt-Project Recovery Integration Tests (REQ-DOC-009)
	var r22 := _exec_sub(TestCorruptRecoveryScript.new(), pass_count, fail_count)
	pass_count = r22[0]; fail_count = r22[1]

	# 23. Run Clone & Save-As Unit Tests (REQ-DOC-010)
	var r23 := _exec_sub(TestCloneScript.new(), pass_count, fail_count)
	pass_count = r23[0]; fail_count = r23[1]

	# 24. Run Asset Library Unit Tests (Milestone 3 — AST-001 through AST-012)
	var asset_test_runner := TestAssetLibraryScript.new()
	add_child(asset_test_runner)
	pass_count += asset_test_runner.run_tests()
	asset_test_runner.queue_free()

	# 25. Run Canvas & Command System Unit Tests (Milestone 4 — CAN-001 through CAN-012)
	var canvas_test_runner := TestCanvasCommandScript.new()
	add_child(canvas_test_runner)
	pass_count += canvas_test_runner.run_tests()
	canvas_test_runner.queue_free()

	# 26. Run Rigging System Unit Tests (Milestone 5 — RIG-001 through RIG-012)
	var rigging_test_runner := TestRiggingScript.new()
	add_child(rigging_test_runner)
	pass_count += rigging_test_runner.run_tests()
	rigging_test_runner.queue_free()

	# 27. Run Constraints & IK System Unit Tests (Milestone 6 — IK-001 through IK-011)
	var ik_test_runner := TestConstraintsIKScript.new()
	add_child(ik_test_runner)
	pass_count += ik_test_runner.run_tests()
	ik_test_runner.queue_free()

	# 28. Run Animation Timeline Unit Tests (Milestone 7 — ANM-001 through ANM-014 + QA-ANM-001)
	var anm_test_runner := TestAnimationTimelineScript.new()
	add_child(anm_test_runner)
	pass_count += anm_test_runner.run_tests()
	anm_test_runner.queue_free()

	# 29. Run Curves & Onion Skinning Unit Tests (Milestone 8 — CRV-001 through CRV-007, ONI-001 through ONI-004 + QA-CRV-001)
	var crv_test_runner := TestCurvesOnionScript.new()
	add_child(crv_test_runner)
	pass_count += crv_test_runner.run_tests()
	crv_test_runner.queue_free()

	# 30. Run Mesh & Deformation Studio Unit Tests (Milestone 9 — MSH-001 through MSH-008, DEF-001 through DEF-006 + QA-DEF-001)
	var def_test_runner := TestMeshDeformationScript.new()
	add_child(def_test_runner)
	pass_count += def_test_runner.run_tests()
	def_test_runner.queue_free()

	# 31. Run Weapon Posing Studio & Gameplay Metadata Unit Tests
	var weapon_gameplay_test_runner := TestWeaponGameplayScript.new()
	add_child(weapon_gameplay_test_runner)
	pass_count += weapon_gameplay_test_runner.run_tests()
	weapon_gameplay_test_runner.queue_free()

	# 32. Run facing grids, state rules, exporters, and Godot runtime tests.
	var facing_export_runtime_test_runner := TestFacingExportRuntimeScript.new()
	add_child(facing_export_runtime_test_runner)
	pass_count += facing_export_runtime_test_runner.run_tests()
	facing_export_runtime_test_runner.queue_free()

	# 33. Verify exported native artifacts in an isolated runtime-only project.
	var r33 := _exec_sub(TestCleanConsumerExportScript.new(), pass_count, fail_count)
	pass_count = r33[0]; fail_count = r33[1]

	# 34. Open each legacy export artifact with an independent reader or decoder.
	var r34 := _exec_sub(TestExportArtifactValidationScript.new(), pass_count, fail_count)
	pass_count = r34[0]; fail_count = r34[1]

	# 35. Exercise facing-grid variants, selection, blending, and persistence independently.
	var r35 := _exec_sub(TestFacingGridAcceptanceScript.new(), pass_count, fail_count)
	pass_count = r35[0]; fail_count = r35[1]

	# 36. Exercise weapon posing and gameplay metadata as one user-facing workflow.
	var r36 := _exec_sub(TestWeaponMetadataAcceptanceScript.new(), pass_count, fail_count)
	pass_count = r36[0]; fail_count = r36[1]

	# 37. Exercise the user-facing 4/8/16/custom direction-set authoring workflow.
	var r37 := _exec_sub(TestFacingDirectionEditorScript.new(), pass_count, fail_count)
	pass_count = r37[0]; fail_count = r37[1]
	# 38. Exercise deterministic preview and application of filename-based directional placement.
	var r38 := _exec_sub(TestFacingFilenamePlacementScript.new(), pass_count, fail_count)
	pass_count = r38[0]; fail_count = r38[1]
	# 39. Exercise pose authoring workflows.
	var r39 := _exec_sub(TestPoseAuthoringScript.new(), pass_count, fail_count)
	pass_count = r39[0]; fail_count = r39[1]
	# 40. Exercise semantic skeleton profiles used by retargeting.
	var r40 := _exec_sub(TestRetargetingScript.new(), pass_count, fail_count)
	pass_count = r40[0]; fail_count = r40[1]
	# 41. Exercise the connected artist workflow added by the Authoring Completion milestone.
	var r41 := _exec_sub(TestAuthoringCompletionScript.new(), pass_count, fail_count)
	pass_count = r41[0]; fail_count = r41[1]
	# 42. Exercise import provenance, scale guidance, release packaging, and local support safeguards.
	var r42 := _exec_sub(TestReleaseHardeningScript.new(), pass_count, fail_count)
	pass_count = r42[0]; fail_count = r42[1]
	# 43. Exercise runtime-contract preview/export, production automation, collaboration, and approval delivery.
	var r43 := _exec_sub(TestProductionDeliveryScript.new(), pass_count, fail_count)
	pass_count = r43[0]; fail_count = r43[1]
	# 44. Exercise the locked LPC catalog, strict reference raster path, and direct-start project workflow.
	var r44 := _exec_sub(TestLpcPhase01Script.new(), pass_count, fail_count)
	pass_count = r44[0]; fail_count = r44[1]
	# 45. Exercise the focused LPC creator and exact native frame export path.
	var r45 := _exec_sub(TestLpcPhase2Script.new(), pass_count, fail_count)
	pass_count = r45[0]; fail_count = r45[1]
	# 46. Exercise project-owned LPC pixel edits, cels, onion state, and derivative persistence.
	var r46 := _exec_sub(TestLpcPhase3Script.new(), pass_count, fail_count)
	pass_count = r46[0]; fail_count = r46[1]
	print("")
	print("=== Test Suite Finished: %d PASS, %d FAIL ===" % [pass_count, fail_count])
	get_tree().quit(0 if fail_count == 0 else 1)
func _exec_sub(runner: Node, p_count: int, f_count: int) -> Array[int]:
	add_child(runner)
	var res: Dictionary = runner.run_all_tests() if runner.has_method("run_all_tests") else runner.run_tests()
	var p: int = p_count + int(res.get("passed", 0))
	var f: int = f_count + int(res.get("failed", 0))
	for err in res.get("errors", []):
		printerr("  FAIL: " + str(err))
	runner.queue_free()
	return [p, f]
