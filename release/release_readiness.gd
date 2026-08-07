# ReleaseReadiness -- Reproducible release-manifest and documentation/sample preflight.
class_name ReleaseReadiness
extends RefCounted

const SampleCatalogScript = preload("res://samples/sample_catalog.gd")

const REQUIRED_DOCUMENTS := ["res://docs/guides/USER_GUIDE.md", "res://docs/guides/ASSET_AUTHORING_GUIDE.md", "res://docs/guides/WEAPON_AUTHORING_GUIDE.md", "res://docs/guides/RELEASE_BUILD_GUIDE.md", "res://docs/guides/PRIVACY_AND_SUPPORT.md", "res://docs/architecture/RUNTIME_PLUGIN_API.md", "res://release/RELEASE_NOTES.md", "res://release/KNOWN_ISSUES.md", "res://release/update_manifest.json", "res://release/release_config.json", "res://release/windows/PaperQuestCharacterStudio.nsi", "res://app/icon.svg", "res://docs/architecture/ASSET_LICENSES.md", "res://docs/architecture/DEPENDENCY_LICENSES.md"]


func build_manifest(version: String = "0.1.0-dev") -> Dictionary:
	return {"version": version, "samples": SampleCatalogScript.new().list_samples(), "documents": REQUIRED_DOCUMENTS.duplicate(), "platform_smoke_required": true, "windows_artifacts": ["portable_zip", "embedded_pck_exe", "nsis_installer"], "code_signing_required_for_public_release": true, "support_bundle_is_opt_in": true, "update_feed_requires_https": true}


func validate() -> Dictionary:
	var missing: Array = []
	for path in REQUIRED_DOCUMENTS:
		if not FileAccess.file_exists(path): missing.append(path)
	var sample_result: Dictionary = SampleCatalogScript.new().validate()
	var config := _read_release_config()
	var config_errors: Array = []
	if config.is_empty(): config_errors.append("release_config.json is invalid")
	elif str(config.get("version", "")).strip_edges().is_empty(): config_errors.append("release_config.json requires a version")
	elif str(config.get("version", "")) != str(ProjectSettings.get_setting("application/config/version", "")): config_errors.append("release_config.json version must match application/config/version")
	return {"valid": missing.is_empty() and config_errors.is_empty() and sample_result.get("valid", false), "missing_documents": missing, "config_errors": config_errors, "release_config": config, "samples": sample_result, "manifest": build_manifest(str(config.get("version", "0.1.0-dev")))}


func _read_release_config() -> Dictionary:
	var file := FileAccess.open("res://release/release_config.json", FileAccess.READ)
	if file == null: return {}
	var value = JSON.parse_string(file.get_as_text())
	file.close()
	if value is Dictionary: return value as Dictionary
	return {}
