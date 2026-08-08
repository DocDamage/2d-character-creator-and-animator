# LpcDeliveryExporter -- Baked, editable-runtime, and hybrid LPC delivery profiles with portable manifests.
class_name LpcDeliveryExporter
extends RefCounted

const ProfileScript = preload("res://lpc/project/lpc_project_profile.gd")
const RigAdapterScript = preload("res://lpc/rig/lpc_rig_adapter.gd")
const WeightedMeshScript = preload("res://lpc/rig/lpc_weighted_mesh.gd")
const DirectionScript = preload("res://lpc/rig/lpc_direction_authoring.gd")
const HybridExporterScript = preload("res://lpc/export/lpc_hybrid_exporter.gd")
const RuntimeBuilderScript = preload("res://lpc/export/lpc_runtime_delivery_builder.gd")
const ClipSchemaScript = preload("res://lpc/animation/lpc_typed_clip_schema.gd")
const LicenseResolverScript = preload("res://lpc/licensing/lpc_license_resolver.gd")
const RuntimeImporterScript = preload("res://addons/modular_character_runtime/runtime/chrproj_importer.gd")

const PROFILES := ["BAKED_FRAMES", "EDITABLE_GODOT_RUNTIME", "HYBRID_RUNTIME"]


static func export_profile(catalog: Dictionary, profile: Dictionary, output_directory: String, options: Dictionary = {}) -> Dictionary:
	var profile_id := str(options.get("profile_id", "BAKED_FRAMES")).to_upper()
	if profile_id not in PROFILES: return {"success": false, "errors": ["Unknown LPC delivery profile '%s'." % profile_id]}
	var validation := validate(catalog, profile, profile_id)
	if not validation.is_empty(): return {"success": false, "errors": validation}
	var absolute := _absolute(output_directory)
	if DirAccess.make_dir_recursive_absolute(absolute) != OK: return {"success": false, "errors": ["Could not create the LPC delivery folder."]}
	var baked := _export_baked(catalog, profile, output_directory, options) if profile_id in ["BAKED_FRAMES", "HYBRID_RUNTIME"] else {"success": true, "frames": [], "manifest": ""}
	if not bool(baked.get("success", false)): return baked
	if profile_id == "BAKED_FRAMES":
		var baked_manifest := {"format": "lpc_delivery", "profile": profile_id, "baked": baked, "credits": _credits(catalog, profile), "source_lock": profile.get("source_lock", {}), "profile_schema_version": profile.get("profile_schema_version", "")}
		var manifest_path := output_directory.path_join("lpc_delivery_manifest.json"); _write_json(manifest_path, baked_manifest)
		return {"success": true, "errors": [], "profile": profile_id, "manifest": manifest_path, "baked": baked}
	var unsupported := _unsupported_runtime_features(profile)
	if profile_id == "EDITABLE_GODOT_RUNTIME" and not unsupported.is_empty(): return {"success": false, "errors": ["Editable runtime cannot represent: " + ", ".join(unsupported) + ". Use the explicit Hybrid Runtime profile with baked fallback."]}
	var assets := _copy_runtime_assets(catalog, profile, output_directory)
	if not bool(assets.get("success", false)): return assets
	var runtime_project := _runtime_project(profile, assets, baked, unsupported, profile_id, _credits(catalog, profile))
	var package_path := output_directory.path_join("lpc_runtime.chrproj")
	if not _write_json(package_path, runtime_project): return {"success": false, "errors": ["Could not write editable LPC runtime project data."]}
	var addon := _copy_tree("res://addons/modular_character_runtime", output_directory.path_join("addons/modular_character_runtime"))
	if not addon: return {"success": false, "errors": ["Could not include the clean-consumer runtime addon."]}
	var runtime_resource_path := output_directory.path_join("lpc_runtime.tres")
	var imported := RuntimeImporterScript.new().import_file(package_path, runtime_resource_path)
	if not bool(imported.get("success", false)): return {"success": false, "errors": imported.get("errors", ["Could not write portable LPC runtime resource."])}
	var runtime_scene_path := output_directory.path_join("lpc_character.tscn")
	if not _write_runtime_scene(runtime_scene_path): return {"success": false, "errors": ["Could not write portable LPC runtime scene."]}
	var manifest := {"format": "lpc_delivery", "profile": profile_id, "runtime_package": "lpc_runtime.chrproj", "runtime_resource": "lpc_runtime.tres", "runtime_scene": "lpc_character.tscn", "runtime_addon": "addons/modular_character_runtime", "assets": assets.get("manifest", {}), "baked": baked, "unsupported_features": unsupported, "fallback_policy": "explicit_baked_frames" if profile_id == "HYBRID_RUNTIME" and not unsupported.is_empty() else "none", "credits": _credits(catalog, profile), "source_lock": profile.get("source_lock", {}), "profile_schema_version": profile.get("profile_schema_version", "")}
	var manifest_path := output_directory.path_join("lpc_delivery_manifest.json")
	if not _write_json(manifest_path, manifest): return {"success": false, "errors": ["Could not write the LPC delivery manifest."]}
	return {"success": true, "errors": [], "profile": profile_id, "manifest": manifest_path, "runtime_package": package_path, "runtime_resource": runtime_resource_path, "runtime_scene": runtime_scene_path, "baked": baked, "unsupported_features": unsupported}


static func validate(catalog: Dictionary, profile: Dictionary, profile_id: String) -> Array[String]:
	var errors: Array[String] = ProfileScript.validate(profile)
	errors.append_array(DirectionScript.validate(profile))
	var derivative_ids := RigAdapterScript.derivative_id_map(profile); var adapters: Dictionary = {}
	for raw in profile.get("rig_adapters", []):
		if not raw is Dictionary: errors.append("Project contains an invalid LPC rig adapter."); continue
		var adapter: Dictionary = raw; errors.append_array(RigAdapterScript.validate(adapter, derivative_ids)); adapters[str(adapter.get("instance_id", ""))] = adapter
	for raw in profile.get("weighted_meshes", []):
		if not raw is Dictionary: errors.append("Project contains an invalid LPC weighted mesh."); continue
		var mesh: Dictionary = raw; var adapter: Dictionary = adapters.get(str(mesh.get("rig_adapter_id", "")), {}); errors.append_array(WeightedMeshScript.validate(mesh, adapter.get("bones", {}) as Dictionary, derivative_ids))
	if str((profile.get("direction_set", {}) as Dictionary).get("id", "")) == "lpc_authored_8" and not bool(DirectionScript.completion(profile).get("complete", false)): errors.append("Eight-direction LPC export is incomplete; author every required diagonal explicitly.")
	if profile_id != "BAKED_FRAMES" and (profile.get("rig_adapters", []) as Array).is_empty(): errors.append("Editable LPC runtime export needs at least one prepared cutout rig.")
	return errors


static func _export_baked(catalog: Dictionary, profile: Dictionary, output_directory: String, options: Dictionary) -> Dictionary:
	var clips: Array = profile.get("clips", []); if clips.is_empty(): return {"success": false, "errors": ["Create a typed LPC clip before exporting baked delivery frames."]}
	var clip_id := str(options.get("clip_id", "")); var clip := ClipSchemaScript.find(profile, clip_id) if not clip_id.is_empty() else (clips[0] as Dictionary).duplicate(true)
	if clip.is_empty(): return {"success": false, "errors": ["The requested LPC delivery clip is unavailable."]}
	return HybridExporterScript.export_clip(catalog, profile, clip, output_directory.path_join("baked"))


static func _copy_runtime_assets(catalog: Dictionary, profile: Dictionary, root: String) -> Dictionary:
	var manifest := {"sources": [], "derivatives": []}; var source_root := str(catalog.get("source_root", ""))
	for raw in profile.get("selections", []):
		if not raw is Dictionary: continue
		var asset: Dictionary = (catalog.get("assets", {}) as Dictionary).get(str((raw as Dictionary).get("asset_id", "")), {})
		var relative := str(asset.get("source_relative_path", "")); var from := source_root.path_join(relative); var to_relative := "assets/sources/" + str(asset.get("asset_id", "")) + ".png"; var to := root.path_join(to_relative)
		if relative.is_empty() or not _copy_file(from, to): return {"success": false, "errors": ["Could not package immutable LPC source '%s'." % asset.get("asset_id", "")]}
		manifest.sources.append({"asset_id": asset.get("asset_id", ""), "file": to_relative, "source_hash": asset.get("source_sha256", "")})
	for raw in profile.get("derivative_references", []):
		if not raw is Dictionary: continue
		var derivative: Dictionary = raw; var hash := str(derivative.get("content_hash", "")); var to_relative := "assets/derivatives/" + hash + ".png"; var to := root.path_join(to_relative)
		if hash.is_empty() or not _copy_file(str(derivative.get("blob_path", "")), to): return {"success": false, "errors": ["Could not package project-owned LPC derivative '%s'." % derivative.get("derivative_id", "")]}
		manifest.derivatives.append({"derivative_id": derivative.get("derivative_id", ""), "content_hash": hash, "file": to_relative, "ancestry": derivative.get("ancestor_derivative_ids", [])})
	return {"success": true, "errors": [], "manifest": manifest}


static func _runtime_project(profile: Dictionary, assets: Dictionary, baked: Dictionary, unsupported: Array, profile_id: String, credits: Dictionary = {}) -> Dictionary:
	# This is source project data for the portable runtime importer. The importer wraps it in its runtime-package envelope.
	return RuntimeBuilderScript.build(profile, assets, baked, unsupported, profile_id, credits)


static func _runtime_rig(profile: Dictionary) -> Dictionary:
	var output: Dictionary = {"bones": {}}
	var adapters: Array = profile.get("rig_adapters", []); if adapters.is_empty(): return output
	var adapter: Dictionary = adapters[0] as Dictionary
	for bone_id in (adapter.get("bones", {}) as Dictionary):
		var bone: Dictionary = adapter.bones[bone_id]; output.bones[bone_id] = {"name": bone_id, "parent_id": bone.get("parent_id", ""), "local_position": bone.get("rest_position", [0, 0]), "local_rotation": deg_to_rad(float(bone.get("rest_rotation_degrees", 0.0))), "length": bone.get("length", 0.0)}
	return output


static func _unsupported_runtime_features(profile: Dictionary) -> Array:
	var output: Array[String] = []
	for raw in profile.get("weighted_meshes", []):
		if not raw is Dictionary: continue
		var state: Dictionary = (raw as Dictionary).get("control_state", {})
		if not (state.get("cage", {}) as Dictionary).is_empty() and "mean_value_cage" not in output: output.append("mean_value_cage")
		if not (state.get("soft_drags", []) as Array).is_empty() and "soft_drag" not in output: output.append("soft_drag")
	return output
static func _credits(catalog: Dictionary, profile: Dictionary) -> Dictionary:
	var assets: Array = []; for raw in profile.get("selections", []): if raw is Dictionary: var asset: Dictionary = (catalog.get("assets", {}) as Dictionary).get(str((raw as Dictionary).get("asset_id", "")), {}); if not asset.is_empty(): assets.append(asset)
	var policy: Dictionary = profile.get("policy", {}); return LicenseResolverScript.exact_credit_manifest(assets, str(policy.get("profile_id", "full_source")), profile.get("selected_license_options", {}), policy.get("custom", {}))
static func _copy_file(from: String, to: String) -> bool:
	if from.is_empty() or not FileAccess.file_exists(from): return false
	var parent := to.get_base_dir(); if DirAccess.make_dir_recursive_absolute(_absolute(parent)) != OK: return false
	return DirAccess.copy_absolute(_absolute(from), _absolute(to)) == OK
static func _copy_tree(from: String, to: String) -> bool:
	var directory := DirAccess.open(from); if directory == null or DirAccess.make_dir_recursive_absolute(_absolute(to)) != OK: return false
	directory.list_dir_begin(); var entry := directory.get_next()
	while not entry.is_empty():
		if entry != "." and entry != "..":
			var source := from.path_join(entry); var destination := to.path_join(entry)
			if directory.current_is_dir():
				if not _copy_tree(source, destination): directory.list_dir_end(); return false
			elif not entry.ends_with(".uid") and not _copy_file(source, destination): directory.list_dir_end(); return false
		entry = directory.get_next()
	directory.list_dir_end(); return true
static func _write_json(path: String, value: Dictionary) -> bool:
	if DirAccess.make_dir_recursive_absolute(_absolute(path.get_base_dir())) != OK: return false
	var file := FileAccess.open(path, FileAccess.WRITE); if file == null: return false
	file.store_string(JSON.stringify(value, "\t")); file.close(); return true
static func _write_runtime_scene(path: String) -> bool:
	if DirAccess.make_dir_recursive_absolute(_absolute(path.get_base_dir())) != OK: return false
	var file := FileAccess.open(path, FileAccess.WRITE); if file == null: return false
	file.store_string("[gd_scene load_steps=3 format=3]\n\n[ext_resource type=\"Script\" path=\"res://addons/modular_character_runtime/runtime/character_player_2d.gd\" id=\"1_player\"]\n[ext_resource type=\"Resource\" path=\"res://lpc_runtime.tres\" id=\"2_data\"]\n\n[node name=\"LpcCharacter\" type=\"Node2D\"]\nscript = ExtResource(\"1_player\")\nruntime_data = ExtResource(\"2_data\")\n")
	file.close(); return true
static func _absolute(path: String) -> String: return ProjectSettings.globalize_path(path) if path.begins_with("res://") or path.begins_with("user://") else path
