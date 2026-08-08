# LpcRuntimeDeliveryBuilder -- Converts persistent LPC rig data into portable runtime-only mappings.
class_name LpcRuntimeDeliveryBuilder
extends RefCounted

const RigEvaluatorScript = preload("res://lpc/rig/lpc_rig_evaluator.gd")


static func build(profile: Dictionary, assets: Dictionary, baked: Dictionary, unsupported: Array, profile_id: String, credits: Dictionary = {}) -> Dictionary:
	var clips: Array = (profile.get("clips", []) as Array).duplicate(true)
	return {
		"project_id": profile.get("project_uuid", ""),
		"lpc_runtime_schema_version": "1.1.0",
		"rig": _rig(profile),
		"clips": clips,
		"runtime_tracks": _tracks(clips),
		"state_machine": _state_machine(clips),
		"clip_durations": _clip_durations(clips),
		"facing_grid": _facing_grid(profile),
		"direction_set": profile.get("direction_set", {}),
		"direction_authoring": profile.get("direction_authoring", {}),
		"lpc_rig_adapters": profile.get("rig_adapters", []),
		"lpc_weighted_meshes": profile.get("weighted_meshes", []),
		"lpc_assets": assets.get("manifest", {}),
		"godot_runtime": _godot_runtime(profile, assets, baked, unsupported),
		"appearance": _appearance(profile),
		"credits": credits.duplicate(true),
		"baked_fallback": {
			"manifest": "baked/lpc_hybrid_manifest.json",
			"available": not str(baked.get("manifest", "")).is_empty(),
			"required_for": unsupported.duplicate(),
		},
		"runtime_profile": profile_id,
		"metadata": {
			"authoring_mode": "lpc_direct_start",
			"source_lock": profile.get("source_lock", {}),
			"delivery_profile": profile_id,
		},
	}


static func _rig(profile: Dictionary) -> Dictionary:
	var output: Dictionary = {"bones": {}}
	var adapters: Array = profile.get("rig_adapters", [])
	if adapters.is_empty() or not adapters[0] is Dictionary:
		return output
	var adapter: Dictionary = adapters[0]
	for bone_id in (adapter.get("bones", {}) as Dictionary):
		var bone: Dictionary = adapter.get("bones", {}).get(bone_id, {})
		output["bones"][str(bone_id)] = {
			"name": bone_id,
			"parent_id": bone.get("parent_id", ""),
			"local_position": bone.get("rest_position", [0, 0]),
			"local_rotation": deg_to_rad(float(bone.get("rest_rotation_degrees", 0.0))),
			"length": bone.get("length", 0.0),
		}
	return output


static func _godot_runtime(profile: Dictionary, assets: Dictionary, baked: Dictionary, unsupported: Array) -> Dictionary:
	var mapping := _asset_paths(assets)
	var selection_slots := _selection_slots(profile)
	var sprites: Array = []
	var meshes: Array = []
	var markers: Array = []
	var weapons: Array = []
	for raw_adapter in profile.get("rig_adapters", []):
		if not raw_adapter is Dictionary:
			continue
		var adapter: Dictionary = raw_adapter
		var transforms := RigEvaluatorScript.bone_transforms(adapter, {})
		var rest: Dictionary = transforms.get("rest", {})
		var direction_id := str(adapter.get("direction_id", ""))
		var source_instance_id := str((adapter.get("source_binding", {}) as Dictionary).get("source_instance_id", ""))
		var source_asset_id := str((adapter.get("source_binding", {}) as Dictionary).get("source_asset_id", ""))
		var z_groups: Dictionary = adapter.get("z_groups", {})
		var grips: Dictionary = {}
		for anchor_id in (adapter.get("anchors", {}) as Dictionary):
			var anchor: Dictionary = (adapter.get("anchors", {}) as Dictionary).get(anchor_id, {})
			var bone_id := str(anchor.get("bone_id", ""))
			var anchor_record := {"bone_id": bone_id, "position": anchor.get("position", [0, 0])}
			grips[str(anchor_id)] = anchor_record
			var anchor_origin := (rest.get(bone_id, Transform2D.IDENTITY) as Transform2D).origin
			var anchor_position := _vector(anchor.get("position", [0, 0]))
			markers.append({"marker_id": "anchor:%s:%s" % [adapter.get("instance_id", ""), anchor_id], "position": [anchor_position.x - anchor_origin.x, anchor_position.y - anchor_origin.y], "bone_id": bone_id, "direction_ids": [direction_id]})
		weapons.append({"weapon_id": "lpc_rig:" + str(adapter.get("instance_id", "")), "grips": grips})
		for raw_piece in adapter.get("pieces", []):
			if not raw_piece is Dictionary:
				continue
			var piece: Dictionary = raw_piece
			var strategy := str(piece.get("strategy", "RIGID_CUTOUT")).to_upper()
			if strategy == "HIDDEN":
				continue
			var texture_path := _derivative_path(mapping, str(piece.get("derivative_id", "")))
			if texture_path.is_empty():
				continue
			var bone_id := str(piece.get("bone_id", ""))
			var origin := (rest.get(bone_id, Transform2D.IDENTITY) as Transform2D).origin
			var record := {
				"sprite_id": "rig:%s:%s" % [adapter.get("instance_id", ""), piece.get("piece_id", "")],
				"mesh_id": "skin:%s:%s" % [adapter.get("instance_id", ""), piece.get("piece_id", "")],
				"asset_id": source_asset_id,
				"instance_id": source_instance_id,
				"piece_id": piece.get("piece_id", ""),
				"slot_id": str(piece.get("slot_id", selection_slots.get(source_instance_id, piece.get("z_group", "")))),
				"texture_path": texture_path,
				"bone_id": bone_id,
				"position": [-origin.x, -origin.y],
				"z_index": int(z_groups.get(str(piece.get("z_group", "middle")), 0)) + int(piece.get("z_offset", 0)),
				"direction_ids": [direction_id],
				"centered": false,
			}
			var weighted := _weighted_mesh(profile, str(adapter.get("instance_id", "")), str(piece.get("piece_id", "")))
			if strategy == "WEIGHTED_MESH" and not weighted.is_empty():
				record["texture_path"] = _derivative_path(mapping, str(weighted.get("derivative_id", piece.get("derivative_id", ""))))
				meshes.append(_mesh_record(record, weighted))
			else:
				sprites.append(record)
	return {
		"animation_library": _animation_library(profile.get("clips", [])),
		"sprites": sprites,
		"meshes": meshes,
		"markers": markers,
		"weapons": weapons,
		"appearance": _appearance(profile),
		"baked_fallback": {"manifest": "baked/lpc_hybrid_manifest.json", "available": not str(baked.get("manifest", "")).is_empty(), "required_for": unsupported.duplicate()},
	}


static func _mesh_record(base: Dictionary, mesh: Dictionary) -> Dictionary:
	var output := base.duplicate(true)
	var vertices: Array = []
	for point in mesh.get("rest_vertices", []):
		vertices.append({"position": point})
	output["vertices"] = vertices
	output["uvs"] = (mesh.get("uvs", []) as Array).duplicate(true)
	output["triangle_indices"] = (mesh.get("triangle_indices", []) as Array).duplicate(true)
	output["weights_by_bone"] = _weights_by_bone(mesh)
	return output


static func _weights_by_bone(mesh: Dictionary) -> Dictionary:
	var count := (mesh.get("rest_vertices", []) as Array).size()
	var result: Dictionary = {}
	var weight_sets: Array = mesh.get("weights", [])
	for index in range(count):
		var influences: Array = weight_sets[index] if index < weight_sets.size() and weight_sets[index] is Array else []
		for raw_influence in influences:
			if not raw_influence is Dictionary:
				continue
			var influence: Dictionary = raw_influence
			var bone_id := str(influence.get("bone_id", ""))
			if bone_id.is_empty():
				continue
			if not result.has(bone_id):
				result[bone_id] = _zeroes(count)
			(result[bone_id] as Array)[index] = float(influence.get("weight", 0.0))
	return result


static func _zeroes(count: int) -> Array:
	var output: Array = []
	for _index in range(count):
		output.append(0.0)
	return output


static func _animation_library(raw_clips: Variant) -> Dictionary:
	var output: Dictionary = {}
	if not raw_clips is Array:
		return output
	for raw_clip in raw_clips:
		if not raw_clip is Dictionary:
			continue
		var clip: Dictionary = raw_clip
		var clip_id := str(clip.get("clip_id", ""))
		if not clip_id.is_empty():
			output[clip_id] = {"length": float(clip.get("duration", 0.1)), "loop": bool(clip.get("loop", true))}
	return output


static func _tracks(raw_clips: Variant) -> Dictionary:
	var output: Dictionary = {}
	if not raw_clips is Array:
		return output
	for raw_clip in raw_clips:
		if raw_clip is Dictionary:
			var clip: Dictionary = raw_clip
			output[str(clip.get("clip_id", ""))] = (clip.get("tracks", []) as Array).duplicate(true)
	return output


static func _state_machine(raw_clips: Variant) -> Dictionary:
	var states: Dictionary = {}
	var entry := ""
	if raw_clips is Array:
		for raw_clip in raw_clips:
			if not raw_clip is Dictionary:
				continue
			var clip: Dictionary = raw_clip
			var clip_id := str(clip.get("clip_id", ""))
			if clip_id.is_empty():
				continue
			states[clip_id] = {"clip_id": clip_id, "loop": bool(clip.get("loop", true))}
			if entry.is_empty():
				entry = clip_id
	return {"entry_state_id": entry, "states": states, "transitions": [], "parameters": {}}


static func _clip_durations(raw_clips: Variant) -> Dictionary:
	var output: Dictionary = {}
	if raw_clips is Array:
		for raw_clip in raw_clips:
			if raw_clip is Dictionary:
				var clip: Dictionary = raw_clip
				output[str(clip.get("clip_id", ""))] = float(clip.get("duration", 0.1))
	return output


static func _facing_grid(profile: Dictionary) -> Dictionary:
	var direction_set: Dictionary = profile.get("direction_set", {})
	var directions: Array = (direction_set.get("directions", []) as Array).duplicate(true)
	var records: Dictionary = (profile.get("direction_authoring", {}) as Dictionary).get("directions", {})
	var cells: Dictionary = {}
	for direction_id in directions:
		cells[str(direction_id)] = (records.get(str(direction_id), {"direction_id": direction_id, "representation": "NATIVE"}) as Dictionary).duplicate(true)
	return {"grid_id": "lpc_authored_directions", "direction_set": directions.size(), "custom_directions": directions, "cells": cells, "pixel_mode": true, "default_blend_mode": 0}


static func _appearance(profile: Dictionary) -> Dictionary:
	var equipment: Dictionary = {}
	for raw_selection in profile.get("selections", []):
		if not raw_selection is Dictionary:
			continue
		var selection: Dictionary = raw_selection
		var slot_id := str(selection.get("layer_group", selection.get("slot_id", "")))
		if not slot_id.is_empty():
			equipment[slot_id] = {"asset_id": selection.get("asset_id", ""), "instance_id": selection.get("instance_id", "")}
	return {"selections": (profile.get("selections", []) as Array).duplicate(true), "equipment": equipment}


static func _selection_slots(profile: Dictionary) -> Dictionary:
	var output: Dictionary = {}
	for raw_selection in profile.get("selections", []):
		if raw_selection is Dictionary:
			var selection: Dictionary = raw_selection
			output[str(selection.get("instance_id", ""))] = str(selection.get("slot_id", ""))
	return output


static func _asset_paths(assets: Dictionary) -> Dictionary:
	var derivatives: Dictionary = {}
	for raw in (assets.get("manifest", assets) as Dictionary).get("derivatives", []):
		if raw is Dictionary:
			derivatives[str((raw as Dictionary).get("derivative_id", ""))] = "res://" + str((raw as Dictionary).get("file", ""))
	return {"derivatives": derivatives}


static func _derivative_path(mapping: Dictionary, derivative_id: String) -> String:
	return str((mapping.get("derivatives", {}) as Dictionary).get(derivative_id, ""))


static func _weighted_mesh(profile: Dictionary, adapter_id: String, piece_id: String) -> Dictionary:
	for raw_mesh in profile.get("weighted_meshes", []):
		if raw_mesh is Dictionary:
			var mesh: Dictionary = raw_mesh
			if str(mesh.get("rig_adapter_id", "")) == adapter_id and str(mesh.get("piece_id", "")) == piece_id:
				return mesh.duplicate(true)
	return {}


static func _vector(value: Variant) -> Vector2:
	if value is Vector2: return value
	if value is Vector2i: return Vector2(value)
	if value is Array and (value as Array).size() >= 2: return Vector2(float(value[0]), float(value[1]))
	return Vector2.ZERO
