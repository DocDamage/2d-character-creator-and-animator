# SecondaryMotionLibrary -- Authoring helpers for exportable secondary-motion parameters.
class_name SecondaryMotionLibrary
extends RefCounted

const ProductionDataScript = preload("res://production/production_project_data.gd")
const EvaluatorScript = preload("res://animation/secondary/secondary_motion_evaluator.gd")


static func add_chain(production: Dictionary, chain_id: String, bone_ids: Array, options: Dictionary = {}) -> Dictionary:
	var data := ProductionDataScript.normalize(production)
	var section: Dictionary = data["secondary_motion"].duplicate(true)
	var chains: Dictionary = section.get("chains", {}).duplicate(true)
	var clean_id := chain_id.strip_edges().to_snake_case()
	if clean_id.is_empty() or bone_ids.is_empty(): return {"success": false, "errors": ["A chain ID and at least one bone are required."]}
	chains[clean_id] = {"chain_id": clean_id, "display_name": str(options.get("display_name", clean_id.capitalize())), "kind": str(options.get("kind", "spring")), "bone_ids": bone_ids.duplicate(), "stiffness": clampf(float(options.get("stiffness", 80.0)), 0.0, 1000.0), "damping": clampf(float(options.get("damping", 12.0)), 0.0, 1000.0), "gravity": (options.get("gravity", [0.0, 0.0]) as Array).duplicate(), "max_offset": maxf(0.0, float(options.get("max_offset", 48.0))), "enabled": bool(options.get("enabled", true))}
	section["chains"] = chains
	data["secondary_motion"] = section
	return {"success": true, "data": data, "chain": chains[clean_id]}


static func add_weapon_trail(production: Dictionary, trail_id: String, weapon_id: String, action_point_id: String, options: Dictionary = {}) -> Dictionary:
	var data := ProductionDataScript.normalize(production)
	var section: Dictionary = data["secondary_motion"].duplicate(true)
	var trails: Dictionary = section.get("weapon_trails", {}).duplicate(true)
	var clean_id := trail_id.strip_edges().to_snake_case()
	if clean_id.is_empty() or action_point_id.strip_edges().is_empty(): return {"success": false, "errors": ["A trail ID and action point are required."]}
	trails[clean_id] = {"trail_id": clean_id, "weapon_id": weapon_id.strip_edges(), "action_point_id": action_point_id.strip_edges(), "width": maxf(0.0, float(options.get("width", 8.0))), "lifetime": maxf(0.0, float(options.get("lifetime", 0.12))), "color": (options.get("color", [1.0, 1.0, 1.0, 1.0]) as Array).duplicate(), "event_gate": str(options.get("event_gate", "")), "enabled": bool(options.get("enabled", true))}
	section["weapon_trails"] = trails
	data["secondary_motion"] = section
	return {"success": true, "data": data, "trail": trails[clean_id]}


static func add_impact_frame(production: Dictionary, impact_id: String, clip_id: String, time: float, options: Dictionary = {}) -> Dictionary:
	var data := ProductionDataScript.normalize(production)
	var section: Dictionary = data["secondary_motion"].duplicate(true)
	var impacts: Dictionary = section.get("impact_frames", {}).duplicate(true)
	var clean_id := impact_id.strip_edges().to_snake_case()
	if clean_id.is_empty() or clip_id.strip_edges().is_empty(): return {"success": false, "errors": ["An impact ID and clip are required."]}
	impacts[clean_id] = {"impact_id": clean_id, "clip_id": clip_id.strip_edges(), "time": maxf(0.0, time), "duration": clampf(float(options.get("duration", 0.04)), 0.001, 1.0), "scale": maxf(0.0, float(options.get("scale", 1.0))), "tint": (options.get("tint", [1.0, 1.0, 1.0, 1.0]) as Array).duplicate(), "enabled": bool(options.get("enabled", true))}
	section["impact_frames"] = impacts
	data["secondary_motion"] = section
	return {"success": true, "data": data, "impact_frame": impacts[clean_id]}


static func add_event_effect(production: Dictionary, effect_id: String, event_name: String, action_point_id: String, options: Dictionary = {}) -> Dictionary:
	var data := ProductionDataScript.normalize(production)
	var section: Dictionary = data["secondary_motion"].duplicate(true)
	var effects: Dictionary = section.get("event_effects", {}).duplicate(true)
	var clean_id := effect_id.strip_edges().to_snake_case()
	if clean_id.is_empty() or event_name.strip_edges().is_empty(): return {"success": false, "errors": ["An effect ID and animation event are required."]}
	effects[clean_id] = {"effect_id": clean_id, "event_name": event_name.strip_edges(), "action_point_id": action_point_id.strip_edges(), "effect_type": str(options.get("effect_type", "particle")), "parameters": (options.get("parameters", {}) as Dictionary).duplicate(true), "enabled": bool(options.get("enabled", true))}
	section["event_effects"] = effects
	data["secondary_motion"] = section
	return {"success": true, "data": data, "event_effect": effects[clean_id]}


static func validate(production: Dictionary) -> Array:
	return EvaluatorScript.validate(ProductionDataScript.section(production, "secondary_motion"))
