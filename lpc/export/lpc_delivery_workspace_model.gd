# LpcDeliveryWorkspaceModel -- Persistent delivery profile state and export acceptance records.
class_name LpcDeliveryWorkspaceModel
extends RefCounted

const ExporterScript = preload("res://lpc/export/lpc_delivery_exporter.gd")
const ReleaseCandidateScript = preload("res://lpc/export/lpc_release_candidate.gd")
const ProjectStoreScript = preload("res://lpc/project/lpc_project_store.gd")

signal changed(description: String)

var catalog: Dictionary = {}
var profile: Dictionary = {}
var manifest: Dictionary = {}
var project_path := ""


func bind_context(next_catalog: Dictionary, next_profile: Dictionary, next_manifest: Dictionary = {}, path: String = "") -> Dictionary:
	catalog = next_catalog.duplicate(true); profile = next_profile.duplicate(true); manifest = next_manifest.duplicate(true); project_path = path
	return {"success": not catalog.is_empty(), "errors": [] if not catalog.is_empty() else ["A validated LPC catalog is required."]}


func export_delivery(profile_id: String, output_directory: String, options: Dictionary = {}) -> Dictionary:
	var result := ExporterScript.export_profile(catalog, profile, output_directory, options.merged({"profile_id": profile_id}, true))
	if not bool(result.get("success", false)): return result
	var records: Array = (profile.get("export_profiles", []) as Array).duplicate(true)
	records.append({"profile_id": str(result.get("profile", profile_id)), "manifest": str(result.get("manifest", "")), "runtime_package": str(result.get("runtime_package", "")), "runtime_resource": str(result.get("runtime_resource", "")), "runtime_scene": str(result.get("runtime_scene", "")), "created_at": Time.get_unix_time_from_system(), "unsupported_features": result.get("unsupported_features", [])})
	profile["export_profiles"] = records
	var acceptance: Array = (profile.get("acceptance_records", []) as Array).duplicate(true)
	acceptance.append({"kind": "delivery_export", "profile_id": str(result.get("profile", profile_id)), "manifest": str(result.get("manifest", "")), "time": Time.get_unix_time_from_system()})
	profile["acceptance_records"] = acceptance; profile["runtime_delivery_state"] = {"last_profile_id": str(result.get("profile", profile_id)), "last_manifest": str(result.get("manifest", ""))}
	changed.emit("Exported LPC delivery profile")
	return result


func assess_release_candidate(options: Dictionary = {}) -> Dictionary:
	var result := ReleaseCandidateScript.assess(catalog, profile, options)
	var records: Array = (profile.get("acceptance_records", []) as Array).duplicate(true)
	records.append({"kind": "release_candidate", "time": Time.get_unix_time_from_system(), "success": bool(result.get("success", false)), "release_ready": bool(result.get("release_ready", false)), "errors": result.get("errors", []), "warnings": result.get("warnings", []), "metrics": result.get("metrics", {}), "human_visual_review": result.get("human_visual_review", {})})
	profile["acceptance_records"] = records
	changed.emit("Assessed LPC release candidate")
	return result


func save() -> Dictionary:
	if project_path.is_empty() or manifest.is_empty(): return {"success": false, "errors": ["Bind an LPC project before saving delivery state."]}
	var saved := ProjectStoreScript.save(project_path, manifest, profile)
	if bool(saved.get("success", false)): manifest = saved.manifest.duplicate(true)
	return saved
