# BatchExportController -- Ordered variant exports with cancellation, progress, validation, and open checks.
class_name BatchExportController
extends RefCounted

const PackageExporterScript = preload("res://export/project_format/runtime_package_exporter.gd")
const ValidatorScript = preload("res://export/batch/artifact_validator.gd")

var variants: Array = []
var cancelled: bool = false


func add_variant(variant_id: String, variant_type: String, project_data: Dictionary, metadata: Dictionary = {}) -> bool:
	if variant_id.strip_edges().is_empty() or variant_type not in ["character", "weapon"] or project_data.is_empty() or get_variant(variant_id).size() > 0:
		return false
	variants.append({"variant_id": variant_id, "variant_type": variant_type, "project_data": project_data.duplicate(true), "metadata": metadata.duplicate(true)})
	return true


func get_variant(variant_id: String) -> Dictionary:
	for variant in variants:
		if str((variant as Dictionary).get("variant_id", "")) == variant_id: return (variant as Dictionary).duplicate(true)
	return {}


func request_cancel() -> void:
	cancelled = true


func reset_cancel() -> void:
	cancelled = false


func export_all(output_directory: String, progress: Callable = Callable()) -> Dictionary:
	reset_cancel()
	var results: Array = []
	var total := variants.size()
	for index in range(total):
		if cancelled: return {"success": false, "cancelled": true, "results": results, "progress": float(index) / maxf(1.0, total)}
		var variant := variants[index] as Dictionary
		var path := output_directory.path_join(str(variant.get("variant_id", "variant")) + ".chrpack")
		var result := PackageExporterScript.new().export_project(variant.get("project_data", {}) as Dictionary, path, variant.get("metadata", {}) as Dictionary)
		result["variant_id"] = variant.get("variant_id", "")
		result["variant_type"] = variant.get("variant_type", "")
		results.append(result)
		if progress.is_valid(): progress.call(index + 1, total, result.duplicate(true))
		if not bool(result.get("success", false)): return {"success": false, "cancelled": false, "results": results, "progress": float(index + 1) / maxf(1.0, total)}
	return {"success": true, "cancelled": false, "results": results, "progress": 1.0}


func validate_results(result: Dictionary) -> Dictionary:
	var paths: Array = []
	for item in result.get("results", []) as Array:
		if bool((item as Dictionary).get("success", false)): paths.append(str((item as Dictionary).get("path", "")))
	return ValidatorScript.new().validate_all(paths)


func to_dict() -> Dictionary:
	return {"variants": variants.duplicate(true)}


func from_dict(data: Dictionary) -> BatchExportController:
	variants = (data.get("variants", []) as Array).duplicate(true)
	cancelled = false
	return self
