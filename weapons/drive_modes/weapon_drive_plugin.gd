# WeaponDrivePlugin -- Callable custom drive-mode extension contract.
class_name WeaponDrivePlugin
extends RefCounted

var plugin_id: String = ""
var _resolver: Callable


func _init(p_plugin_id: String = "", p_resolver: Callable = Callable()) -> void:
	plugin_id = p_plugin_id
	_resolver = p_resolver


func is_usable() -> bool:
	return not plugin_id.is_empty() and _resolver.is_valid()


func resolve(profile: Variant, weapon: Variant, rig: Dictionary, context: Dictionary) -> Dictionary:
	if not is_usable():
		return {"success": false, "message": "Custom weapon drive plugin is not configured."}
	var result: Variant = _resolver.call(profile, weapon, rig, context)
	if result is Dictionary:
		return (result as Dictionary).duplicate(true)
	return {"success": false, "message": "Custom weapon drive plugin returned an invalid result."}
