# LpcDeformationWorkspaceModel -- Persistent per-frame LPC warp authoring and verified bake workflow.
class_name LpcDeformationWorkspaceModel
extends RefCounted

const PixelModelScript = preload("res://lpc/pixels/lpc_pixel_canvas_model.gd")
const MeshFactoryScript = preload("res://lpc/deformation/lpc_frame_mesh_factory.gd")
const MeshScript = preload("res://lpc/deformation/lpc_frame_mesh.gd")
const ControlsScript = preload("res://lpc/deformation/lpc_frame_mesh_controls.gd")
const BakerScript = preload("res://lpc/deformation/lpc_strict_frame_baker.gd")
const WarpExporterScript = preload("res://lpc/export/lpc_warp_exporter.gd")
const ProjectStoreScript = preload("res://lpc/project/lpc_project_store.gd")

signal changed(description: String)

var catalog: Dictionary = {}
var profile: Dictionary = {}
var manifest: Dictionary = {}
var project_path := ""
var source: Image
var source_context: Dictionary = {}
var active_mesh_id := ""
var _undo: Array = []
var _redo: Array = []


func bind_context(next_catalog: Dictionary, next_profile: Dictionary, next_manifest: Dictionary = {}, path: String = "") -> Dictionary:
	catalog = next_catalog.duplicate(true)
	profile = next_profile.duplicate(true)
	manifest = next_manifest.duplicate(true)
	project_path = path
	var state: Dictionary = profile.get("deformation_workspace_state", {})
	active_mesh_id = str(state.get("active_mesh_id", ""))
	if not active_mesh_id.is_empty() and _find_mesh(active_mesh_id).is_empty(): active_mesh_id = ""
	return {"success": not catalog.is_empty(), "errors": [] if not catalog.is_empty() else ["A locked LPC catalog is required."]}


func open_native_frame(instance_id: String, animation_id: String = "walk", direction_id: String = "down", logical_frame: int = 0) -> Dictionary:
	var pixels = PixelModelScript.new()
	var opened := pixels.open_native_frame(catalog, profile, instance_id, animation_id, direction_id, logical_frame)
	if not bool(opened.get("success", false)): return opened
	source = pixels.image.duplicate()
	source_context = pixels.source_context.duplicate(true)
	source_context["source_instance_id"] = instance_id
	return {"success": true, "errors": [], "image": source, "context": source_context.duplicate(true)}


func create_mesh(strategy: String = "rectangular_grid", options: Dictionary = {}) -> Dictionary:
	if source == null or source.is_empty(): return {"success": false, "errors": ["Open a native LPC frame before creating a mesh."]}
	var context := source_context.duplicate(true)
	context["mesh_id"] = str(options.get("mesh_id", _default_mesh_id()))
	var generated: Dictionary = {}
	match strategy.to_lower():
		"alpha", "alpha_aware", "alpha_pixel_cells":
			generated = MeshFactoryScript.alpha_aware(source, context, int(options.get("alpha_threshold", 1)))
		"manual":
			var manual_options := options.duplicate(true)
			manual_options["source"] = source
			generated = MeshFactoryScript.manual(context, options.get("rest_vertices", []), options.get("uvs", []), options.get("triangle_indices", []), manual_options)
		_:
			generated = MeshFactoryScript.rectangular_grid(source, context, int(options.get("columns", 4)), int(options.get("rows", 4)), int(options.get("padding", 0)))
	if not bool(generated.get("success", false)): return generated
	var mesh: Dictionary = generated.mesh.duplicate(true)
	mesh["topology_group_id"] = str(options.get("topology_group_id", (source_context.get("source_frame_reference", {}) as Dictionary).get("topology_group_id", "")))
	var provenance: Dictionary = (mesh.get("provenance", {}) as Dictionary).duplicate(true)
	provenance["source_instance_id"] = source_context.get("source_instance_id", "")
	mesh["provenance"] = provenance
	_append_mesh(mesh)
	active_mesh_id = str(mesh.get("mesh_id", ""))
	_set_workspace_state("authoring")
	changed.emit("Created strict frame mesh")
	return {"success": true, "errors": [], "mesh": mesh}


func open_mesh(mesh_id: String) -> Dictionary:
	var mesh := _find_mesh(mesh_id)
	if mesh.is_empty(): return {"success": false, "errors": ["Unknown LPC frame mesh."]}
	if not _source_matches(mesh):
		var loaded := _load_source_for_mesh(mesh)
		if not bool(loaded.get("success", false)): return loaded
	active_mesh_id = mesh_id
	_set_workspace_state("authoring")
	return {"success": true, "errors": [], "mesh": mesh, "image": source}


func active_mesh() -> Dictionary:
	return _find_mesh(active_mesh_id)


func move_vertex(index: int, offset: Variant) -> Dictionary:
	return _mutate("Moved frame-mesh vertex", ControlsScript.set_vertex_offset(active_mesh(), index, offset))


func add_pin(center: Variant, offset: Variant, radius: float, falloff: String = "smooth") -> Dictionary:
	return _mutate("Added radial pin", ControlsScript.add_pin(active_mesh(), center, offset, radius, falloff))


func add_soft_drag(center: Variant, target: Variant, radius: float, falloff: String = "smooth") -> Dictionary:
	return _mutate("Added soft drag", ControlsScript.add_soft_drag(active_mesh(), center, target, radius, falloff))


func set_lattice(lattice: Dictionary) -> Dictionary:
	return _mutate("Updated lattice controls", ControlsScript.set_lattice(active_mesh(), lattice))


func reset_deformation() -> Dictionary:
	return _mutate("Reset deformation", ControlsScript.reset(active_mesh()))


func copy_deformation(from_mesh_id: String) -> Dictionary:
	var source_mesh := _find_mesh(from_mesh_id)
	var target_mesh := active_mesh()
	if source_mesh.is_empty() or target_mesh.is_empty(): return {"success": false, "errors": ["Choose source and target frame meshes first."]}
	if not _topology_compatible(source_mesh, target_mesh): return {"success": false, "errors": ["Deformation can only copy between compatible topology groups."]}
	var next := target_mesh.duplicate(true)
	next["control_state"] = (source_mesh.get("control_state", {}) as Dictionary).duplicate(true)
	return _mutate("Copied compatible deformation", next)


func undo() -> bool:
	if _undo.is_empty(): return false
	var command: Dictionary = _undo.pop_back()
	_replace_mesh(command.before, false)
	_redo.append(command)
	changed.emit("Undid deformation command")
	return true


func redo() -> bool:
	if _redo.is_empty(): return false
	var command: Dictionary = _redo.pop_back()
	_replace_mesh(command.after, false)
	_undo.append(command)
	changed.emit("Redid deformation command")
	return true


func interactive_preview() -> Dictionary:
	var prepared := _ensure_active_source()
	if not bool(prepared.get("success", false)): return prepared
	var result := BakerScript.preview(active_mesh(), source, _bake_options())
	_set_workspace_state("interactive")
	return result


func verify(output_path: String = "") -> Dictionary:
	var prepared := _ensure_active_source()
	if not bool(prepared.get("success", false)): return prepared
	var options := _bake_options()
	if not output_path.is_empty(): options["output_path"] = output_path
	var result := BakerScript.bake(active_mesh(), source, options)
	if bool(result.get("success", false)):
		_record_bake(result)
		_set_workspace_state("verified")
	return result


func export_strict(output_directory: String, options: Dictionary = {}) -> Dictionary:
	var prepared := _ensure_active_source()
	if not bool(prepared.get("success", false)): return prepared
	var export_options := options.duplicate(true)
	export_options["source_asset_id"] = source_context.get("source_asset_id", "")
	export_options["source_asset_sha256"] = source_context.get("source_hash", "")
	var exported := WarpExporterScript.export_mesh(catalog, profile, active_mesh(), source, output_directory, export_options)
	if bool(exported.get("success", false)):
		_record_bake((exported.get("bake", {}) as Dictionary))
		_set_workspace_state("verified")
	return exported


func save() -> Dictionary:
	if project_path.is_empty() or manifest.is_empty(): return {"success": false, "errors": ["Bind an LPC project before saving frame deformation."]}
	var saved := ProjectStoreScript.save(project_path, manifest, profile)
	if bool(saved.get("success", false)): manifest = saved.manifest.duplicate(true)
	return saved


func autosave() -> Dictionary:
	if project_path.is_empty() or manifest.is_empty(): return {"success": false, "errors": ["Bind an LPC project before autosaving frame deformation."]}
	return ProjectStoreScript.autosave(project_path, manifest, profile)


func _mutate(description: String, next: Dictionary) -> Dictionary:
	var current := active_mesh()
	if current.is_empty(): return {"success": false, "errors": ["Create or open an LPC frame mesh first."]}
	var errors := MeshScript.validate(next)
	if not errors.is_empty(): return {"success": false, "errors": errors}
	if JSON.stringify(current.get("control_state", {})) == JSON.stringify(next.get("control_state", {})):
		return {"success": true, "errors": [], "mesh": current}
	_undo.append({"before": current.duplicate(true), "after": next.duplicate(true), "description": description})
	_redo.clear()
	_replace_mesh(next, false)
	_set_workspace_state("authoring")
	changed.emit(description)
	return {"success": true, "errors": [], "mesh": next}


func _append_mesh(mesh: Dictionary) -> void:
	var meshes: Array = (profile.get("frame_meshes", []) as Array).duplicate(true)
	meshes.append(mesh.duplicate(true))
	profile["frame_meshes"] = meshes


func _replace_mesh(mesh: Dictionary, emit_change: bool = true) -> void:
	var meshes: Array = (profile.get("frame_meshes", []) as Array).duplicate(true)
	for index in range(meshes.size()):
		if meshes[index] is Dictionary and str((meshes[index] as Dictionary).get("mesh_id", "")) == str(mesh.get("mesh_id", "")):
			meshes[index] = mesh.duplicate(true)
	profile["frame_meshes"] = meshes
	active_mesh_id = str(mesh.get("mesh_id", active_mesh_id))
	if emit_change: changed.emit("Updated strict frame mesh")


func _find_mesh(mesh_id: String) -> Dictionary:
	for raw in profile.get("frame_meshes", []):
		if raw is Dictionary and str((raw as Dictionary).get("mesh_id", "")) == mesh_id: return (raw as Dictionary).duplicate(true)
	return {}


func _ensure_active_source() -> Dictionary:
	var mesh := active_mesh()
	if mesh.is_empty(): return {"success": false, "errors": ["Create or open an LPC frame mesh first."]}
	if _source_matches(mesh): return {"success": true, "errors": []}
	return _load_source_for_mesh(mesh)


func _source_matches(mesh: Dictionary) -> bool:
	return source != null and not source.is_empty() and str(mesh.get("source_frame_hash", "")) == MeshFactoryScript.image_hash(source)


func _load_source_for_mesh(mesh: Dictionary) -> Dictionary:
	var instance_id := str(((mesh.get("provenance", {}) as Dictionary).get("source_instance_id", "")))
	if instance_id.is_empty():
		for raw in profile.get("selections", []):
			if raw is Dictionary and str((raw as Dictionary).get("asset_id", "")) == str(mesh.get("source_asset_id", "")):
				instance_id = str((raw as Dictionary).get("instance_id", ""))
				break
	if instance_id.is_empty(): return {"success": false, "errors": ["The mesh source layer is no longer selected in this project."]}
	var reference: Dictionary = mesh.get("source_frame_reference", {})
	var loaded := open_native_frame(instance_id, str(reference.get("animation_id", "walk")), str(reference.get("direction_id", "down")), int(reference.get("logical_frame_index", 0)))
	if not bool(loaded.get("success", false)): return loaded
	if not _source_matches(mesh): return {"success": false, "errors": ["The stored mesh is bound to a different source frame and cannot be silently reused."]}
	return loaded


func _record_bake(result: Dictionary) -> void:
	var caches: Array = (profile.get("bake_caches", []) as Array).duplicate(true)
	var artifact: Dictionary = (result.get("artifact", {}) as Dictionary).duplicate(true)
	artifact["cache_kind"] = "strict_frame_warp"
	caches = caches.filter(func(raw): return not (raw is Dictionary and str((raw as Dictionary).get("snapshot_hash", "")) == str(artifact.get("snapshot_hash", ""))))
	caches.append(artifact)
	profile["bake_caches"] = caches


func _set_workspace_state(preview_mode: String) -> void:
	profile["deformation_workspace_state"] = {"active_mesh_id": active_mesh_id, "preview_mode": preview_mode}


func _topology_compatible(left: Dictionary, right: Dictionary) -> bool:
	var left_group := str(left.get("topology_group_id", ""))
	var right_group := str(right.get("topology_group_id", ""))
	if not left_group.is_empty() and left_group == right_group: return true
	return left.get("triangle_indices", []) == right.get("triangle_indices", []) and (left.get("rest_vertices", []) as Array).size() == (right.get("rest_vertices", []) as Array).size()


func _bake_options() -> Dictionary:
	return {
		"source_asset_id": source_context.get("source_asset_id", ""),
		"source_asset_sha256": source_context.get("source_hash", ""),
		"profile": profile,
		"catalog": catalog,
		"credit_manifest_hash": JSON.stringify(profile.get("selected_license_options", {})).sha256_text(),
	}


func _default_mesh_id() -> String:
	var reference: Dictionary = source_context.get("source_frame_reference", {})
	return "warp:%s:%s:%s:%d" % [source_context.get("source_asset_id", "asset"), reference.get("animation_id", "walk"), reference.get("direction_id", "down"), int(reference.get("logical_frame_index", 0))]
