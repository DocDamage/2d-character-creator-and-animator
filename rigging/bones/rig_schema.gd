# RigSchema — Aggregates skeletal bones and slots into a complete character rig manifest
class_name RigSchema
extends RefCounted


static func create_empty_rig(p_id: String = "rig_001", p_name: String = "Default Skeleton") -> Dictionary:
	return {
		"id": p_id,
		"name": p_name,
		"root_bone_id": "",
		"bones": {},
		"slots": {},
		"version": "1.0.0"
	}


static func validate_rig(p_rig: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	if not p_rig.has("id") or str(p_rig.get("id", "")).is_empty():
		errors.append("Rig missing valid 'id'.")
	
	var bones: Dictionary = p_rig.get("bones", {})
	var root_id: String = p_rig.get("root_bone_id", "")
	if not root_id.is_empty() and not bones.has(root_id):
		errors.append("Rig root bone '%s' does not exist in bones dictionary." % root_id)
		
	for b_id in bones:
		var bone_errs := BoneSchema.validate_bone(bones[b_id])
		errors.append_array(bone_errs)
		
	var slots: Dictionary = p_rig.get("slots", {})
	for s_id in slots:
		var slot_errs := SlotSchema.validate_slot(slots[s_id])
		errors.append_array(slot_errs)
		
	return errors


static func to_json_dict(p_rig: Dictionary) -> Dictionary:
	var bones_json := {}
	var bones: Dictionary = p_rig.get("bones", {})
	for b_id in bones:
		bones_json[b_id] = BoneSchema.to_json_dict(bones[b_id])
		
	var slots_json := {}
	var slots: Dictionary = p_rig.get("slots", {})
	for s_id in slots:
		slots_json[s_id] = SlotSchema.to_json_dict(slots[s_id])
		
	return {
		"id": p_rig.get("id", "rig_001"),
		"name": p_rig.get("name", "Skeleton"),
		"root_bone_id": p_rig.get("root_bone_id", ""),
		"bones": bones_json,
		"slots": slots_json,
		"version": p_rig.get("version", "1.0.0")
	}


static func from_json_dict(p_dict: Dictionary) -> Dictionary:
	var bones := {}
	var bones_raw: Dictionary = p_dict.get("bones", {})
	for b_id in bones_raw:
		bones[b_id] = BoneSchema.from_json_dict(bones_raw[b_id])
		
	var slots := {}
	var slots_raw: Dictionary = p_dict.get("slots", {})
	for s_id in slots_raw:
		slots[s_id] = SlotSchema.from_json_dict(slots_raw[s_id])
		
	return {
		"id": p_dict.get("id", "rig_001"),
		"name": p_dict.get("name", "Skeleton"),
		"root_bone_id": p_dict.get("root_bone_id", ""),
		"bones": bones,
		"slots": slots,
		"version": p_dict.get("version", "1.0.0")
	}
