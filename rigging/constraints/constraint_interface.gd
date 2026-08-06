# ConstraintInterface — Base class for all skeletal bone constraints
class_name ConstraintInterface
extends RefCounted

enum ConstraintType { TRANSFORM, AIM, LIMIT, TWO_BONE_IK, POLE_TARGET, CONTACT_PIN }

var id: String = ""
var name: String = ""
var type: ConstraintType = ConstraintType.TRANSFORM
var target_bone_id: String = ""
var owner_bone_id: String = ""
var influence: float = 1.0
var enabled: bool = true
var priority: int = 0


func evaluate(_rig: Dictionary, _delta: float) -> void:
	pass


func to_dict() -> Dictionary:
	return {
		"id": id,
		"name": name,
		"type": type,
		"target_bone_id": target_bone_id,
		"owner_bone_id": owner_bone_id,
		"influence": influence,
		"enabled": enabled,
		"priority": priority
	}
