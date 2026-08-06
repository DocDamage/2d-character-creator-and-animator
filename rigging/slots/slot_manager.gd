# SlotManager — Slot attachment authoring, variant binding, and z-ordering
class_name SlotManager
extends RefCounted

signal slot_added(slot_id: String)
signal slot_removed(slot_id: String)
signal attachment_changed(slot_id: String, attachment_id: String)

var _rig: Dictionary = {}


func initialize(p_rig: Dictionary) -> void:
	_rig = p_rig


func add_slot(p_name: String, p_bone_id: String) -> Dictionary:
	var slots: Dictionary = _rig.get("slots", {})
	var s_id := "slot_%d" % [slots.size() + 1]
	var slot := SlotSchema.create_default_slot(s_id, p_name, p_bone_id)
	slots[s_id] = slot
	_rig["slots"] = slots
	slot_added.emit(s_id)
	return slot


func remove_slot(p_slot_id: String) -> bool:
	var slots: Dictionary = _rig.get("slots", {})
	if not slots.has(p_slot_id):
		return false
	slots.erase(p_slot_id)
	slot_removed.emit(p_slot_id)
	return true


func add_attachment(p_slot_id: String, p_attachment_id: String, p_attachment_data: Dictionary) -> bool:
	var slots: Dictionary = _rig.get("slots", {})
	if not slots.has(p_slot_id):
		return false
	var slot: Dictionary = slots[p_slot_id]
	var attachments: Dictionary = slot.get("attachments", {})
	attachments[p_attachment_id] = p_attachment_data
	slot["attachments"] = attachments
	if str(slot.get("active_attachment_id", "")).is_empty():
		set_active_attachment(p_slot_id, p_attachment_id)
	return true


func set_active_attachment(p_slot_id: String, p_attachment_id: String) -> void:
	var slots: Dictionary = _rig.get("slots", {})
	if not slots.has(p_slot_id):
		return
	var slot: Dictionary = slots[p_slot_id]
	slot["active_attachment_id"] = p_attachment_id
	attachment_changed.emit(p_slot_id, p_attachment_id)


func get_active_attachment(p_slot_id: String) -> Dictionary:
	var slots: Dictionary = _rig.get("slots", {})
	if not slots.has(p_slot_id):
		return {}
	var slot: Dictionary = slots[p_slot_id]
	var active_id: String = slot.get("active_attachment_id", "")
	var attachments: Dictionary = slot.get("attachments", {})
	return attachments.get(active_id, {})
