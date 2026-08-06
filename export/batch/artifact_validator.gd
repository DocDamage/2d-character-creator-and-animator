# ArtifactValidator -- Opens exported artifacts through format-aware readers without authoring dependencies.
class_name ArtifactValidator
extends RefCounted

const RuntimePackageScript = preload("res://export/project_format/runtime_package.gd")


func validate(path: String) -> Dictionary:
	if path.strip_edges().is_empty() or not FileAccess.file_exists(path):
		return {"valid": false, "path": path, "error": "artifact does not exist"}
	var extension := path.get_extension().to_lower()
	match extension:
		"chrpack": return _package(path)
		"png", "webp": return _image(path)
		"gif": return _magic(path, "GIF")
		"mp4": return _magic(path, "ftyp", 4)
		"webm": return _magic(path, "webm")
		"tres": return _resource(path, "Resource")
		"tscn": return _scene(path)
		_: return {"valid": true, "path": path, "kind": "file"}


func validate_all(paths: Array) -> Dictionary:
	var artifacts: Array = []
	var valid := true
	for path in paths:
		var result := validate(str(path))
		artifacts.append(result)
		valid = valid and bool(result.get("valid", false))
	return {"valid": valid, "artifacts": artifacts}


func verify_openable(path: String) -> Dictionary:
	var result := validate(path)
	result["opened"] = bool(result.get("valid", false))
	return result


func _package(path: String) -> Dictionary:
	var result := RuntimePackageScript.load(path)
	return {"valid": bool(result.get("success", false)), "path": path, "kind": "runtime_package", "errors": result.get("errors", [])}


func _image(path: String) -> Dictionary:
	var image := Image.load_from_file(path)
	return {"valid": image != null and not image.is_empty(), "path": path, "kind": "image", "size": image.get_size() if image != null else Vector2i.ZERO}


func _resource(path: String, kind: String) -> Dictionary:
	return {"valid": load(path) != null, "path": path, "kind": kind}


func _scene(path: String) -> Dictionary:
	var scene := load(path) as PackedScene
	var instance = scene.instantiate() if scene != null else null
	if instance != null: instance.free()
	return {"valid": scene != null and instance != null, "path": path, "kind": "scene"}


func _magic(path: String, marker: String, offset: int = 0) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null: return {"valid": false, "path": path, "error": "cannot open artifact"}
	file.seek(offset)
	var sample := file.get_buffer(16).get_string_from_ascii().to_lower()
	file.close()
	return {"valid": marker.to_lower() in sample, "path": path, "kind": "media"}
