# ReleaseReadiness -- Reproducible release-manifest and documentation/sample preflight.
class_name ReleaseReadiness
extends RefCounted

const SampleCatalogScript = preload("res://samples/sample_catalog.gd")

const REQUIRED_DOCUMENTS := ["res://docs/guides/USER_GUIDE.md", "res://docs/guides/ASSET_AUTHORING_GUIDE.md", "res://docs/guides/WEAPON_AUTHORING_GUIDE.md", "res://docs/guides/RELEASE_BUILD_GUIDE.md", "res://docs/architecture/RUNTIME_PLUGIN_API.md", "res://release/RELEASE_NOTES.md", "res://release/KNOWN_ISSUES.md", "res://release/update_manifest.json", "res://app/icon.svg", "res://docs/architecture/ASSET_LICENSES.md", "res://docs/architecture/DEPENDENCY_LICENSES.md"]


func build_manifest(version: String = "0.1.0-dev") -> Dictionary:
	return {"version": version, "samples": SampleCatalogScript.new().list_samples(), "documents": REQUIRED_DOCUMENTS.duplicate(), "platform_smoke_required": true, "windows_artifacts": ["portable_zip", "embedded_pck_exe"], "code_signing_required_for_public_release": true}


func validate() -> Dictionary:
	var missing: Array = []
	for path in REQUIRED_DOCUMENTS:
		if not FileAccess.file_exists(path): missing.append(path)
	var sample_result: Dictionary = SampleCatalogScript.new().validate()
	return {"valid": missing.is_empty() and sample_result.get("valid", false), "missing_documents": missing, "samples": sample_result, "manifest": build_manifest()}
