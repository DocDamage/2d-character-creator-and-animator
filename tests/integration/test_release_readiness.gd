# Integration tests for Phase 8 samples, manuals, release manifest, and reproducibility checks.
extends Node

const SampleCatalogScript = preload("res://samples/sample_catalog.gd")
const ReleaseReadinessScript = preload("res://release/release_readiness.gd")
const ReleaseBuilderScript = preload("res://release/release_builder.gd")


func run_tests() -> int:
	var catalog: Dictionary = SampleCatalogScript.new().validate()
	var release: Dictionary = ReleaseReadinessScript.new().validate()
	var manifest: Dictionary = ReleaseReadinessScript.new().build_manifest("0.1.0-dev")
	var builder := ReleaseBuilderScript.new()
	var preflight: Dictionary = builder.preflight()
	var rejected_path: Dictionary = builder.build_windows("../unsafe.exe")
	if catalog.get("valid", false) and catalog.get("samples", []).size() == 6 and release.get("valid", false) and manifest.get("platform_smoke_required", false) and manifest.get("documents", []).size() >= 9 and preflight.get("ready", false) and preflight.get("required_platform") == "Windows Desktop" and not rejected_path.get("success", true):
		print("  PASS: SMP-001 through SMP-006 and DOCS/REL release catalog, manuals, manifests, and readiness checks are reproducible")
		return 1
	printerr("  FAIL: release samples or documentation readiness validation failed: %s" % str(release))
	return 0
