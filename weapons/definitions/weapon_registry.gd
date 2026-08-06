# WeaponRegistry -- Project-level registry for weapons and pose profiles.
class_name WeaponRegistry
extends RefCounted

var _weapons: Dictionary = {}
var _profiles: Dictionary = {}


func register_weapon(weapon) -> bool:
	if weapon == null or weapon.weapon_id.is_empty() or _weapons.has(weapon.weapon_id):
		return false
	_weapons[weapon.weapon_id] = weapon.to_dict()
	return true


func get_weapon(weapon_id: String):
	if not _weapons.has(weapon_id):
		return null
	var weapon := WeaponDefinition.new()
	weapon.from_dict(_weapons[weapon_id])
	return weapon


func register_profile(profile) -> bool:
	if profile == null or profile.profile_id.is_empty() or _profiles.has(profile.profile_id):
		return false
	if not _weapons.has(profile.weapon_id):
		return false
	_profiles[profile.profile_id] = profile.to_dict()
	return true


func get_profiles_for_weapon(weapon_id: String) -> Array:
	var result: Array = []
	for profile_data in _profiles.values():
		if str(profile_data.get("weapon_id", "")) == weapon_id:
			var profile := WeaponPoseProfile.new()
			profile.from_dict(profile_data)
			result.append(profile)
	return result


func to_dict() -> Dictionary:
	return {"weapons": _weapons.duplicate(true), "pose_profiles": _profiles.duplicate(true)}


func from_dict(data: Dictionary) -> void:
	_weapons = (data.get("weapons", {}) as Dictionary).duplicate(true)
	_profiles = (data.get("pose_profiles", {}) as Dictionary).duplicate(true)
