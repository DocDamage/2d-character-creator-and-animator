# LpcRigWorkspaceModel -- Persistent Prepare for Rig, rigid posing, anchors, and explicit layer strategy workflow.
class_name LpcRigWorkspaceModel
extends RefCounted
const AdapterScript = preload("res://lpc/rig/lpc_rig_adapter.gd")
const AdapterRegistryScript = preload("res://lpc/rig/lpc_rig_adapter_registry.gd")
const PreparationScript = preload("res://lpc/rig/lpc_rig_preparation.gd")
const EvaluatorScript = preload("res://lpc/rig/lpc_rig_evaluator.gd")
const PoseSolverScript = preload("res://lpc/rig/lpc_rig_pose_solver.gd")
const PixelModelScript = preload("res://lpc/pixels/lpc_pixel_canvas_model.gd")
const ProjectStoreScript = preload("res://lpc/project/lpc_project_store.gd")
const WeightedMeshScript = preload("res://lpc/rig/lpc_weighted_mesh.gd")
const WeightInitializerScript = preload("res://lpc/rig/lpc_weight_initializer.gd")
const WeightPainterScript = preload("res://lpc/rig/lpc_weight_painter.gd")
const CageScript = preload("res://lpc/rig/lpc_cage_deformation.gd")
const DirectionAuthoringScript = preload("res://lpc/rig/lpc_direction_authoring.gd")
signal changed(description: String)
var catalog: Dictionary = {}
var profile: Dictionary = {}
var manifest: Dictionary = {}
var project_path := ""
var active_adapter_id := ""
var active_source: Image
var _undo: Array = []
var _redo: Array = []
func bind_context(next_catalog: Dictionary, next_profile: Dictionary, next_manifest: Dictionary = {}, path: String = "") -> Dictionary:
	catalog = next_catalog.duplicate(true); profile = next_profile.duplicate(true); manifest = next_manifest.duplicate(true); project_path = path
	var state: Dictionary = profile.get("rig_workspace_state", {})
	active_adapter_id = str(state.get("active_adapter_id", ""))
	if not active_adapter().is_empty(): _load_source(active_adapter())
	return {"success": not catalog.is_empty(), "errors": [] if not catalog.is_empty() else ["A validated LPC catalog is required."]}
func available_adapters(instance_id: String, direction_id: String) -> Array:
	var found := AdapterRegistryScript.find(catalog, profile, instance_id, direction_id)
	var output: Array = (found.get("adapters", []) as Array).duplicate(true)
	if output.is_empty():
		output.append((found.get("manual_template", AdapterScript.standard_template(str(profile.get("body_family_id", "")), direction_id, {"manual_setup": true, "source_instance_id": instance_id})) as Dictionary).duplicate(true))
	return output
func preview_preparation(instance_id: String, options: Dictionary = {}) -> Dictionary:
	var values := options.duplicate(true)
	var target_direction := str(values.get("target_direction_id", values.get("source_direction_id", "down")))
	if not values.has("template"):
		var found := AdapterRegistryScript.find(catalog, profile, instance_id, target_direction, values)
		if not bool(found.get("success", false)): return found
		var adapters: Array = found.get("adapters", [])
		values["template"] = (adapters[0] as Dictionary).duplicate(true) if not adapters.is_empty() else (found.get("manual_template", {}) as Dictionary).duplicate(true)
	return PreparationScript.preview(catalog, profile, instance_id, values)
func prepare_for_rig(instance_id: String, options: Dictionary = {}) -> Dictionary:
	var values := options.duplicate(true)
	var target_direction := str(values.get("target_direction_id", values.get("source_direction_id", "down")))
	if not values.has("template"):
		var found := AdapterRegistryScript.find(catalog, profile, instance_id, target_direction, values)
		if bool(found.get("success", false)):
			var adapters: Array = found.get("adapters", [])
			values["template"] = (adapters[0] as Dictionary).duplicate(true) if not adapters.is_empty() else (found.get("manual_template", {}) as Dictionary).duplicate(true)
	var before := profile.duplicate(true); var prepared := PreparationScript.prepare(catalog, profile, instance_id, values)
	if not bool(prepared.get("success", false)): return prepared
	profile = (prepared.get("profile", {}) as Dictionary).duplicate(true); active_adapter_id = str((prepared.get("adapter", {}) as Dictionary).get("instance_id", "")); active_source = prepared.get("source", null)
	_set_state(); _record("Prepare LPC art for rig", before, profile)
	changed.emit("Prepared LPC art as reversible cutout rig")
	return prepared
func open_adapter(adapter_id: String) -> Dictionary:
	var adapter := _find_adapter(adapter_id)
	if adapter.is_empty(): return {"success": false, "errors": ["Unknown LPC cutout rig."]}
	active_adapter_id = adapter_id; var source := _load_source(adapter); _set_state()
	return {"success": bool(source.get("success", false)), "errors": source.get("errors", []), "adapter": adapter, "image": active_source}
func active_adapter() -> Dictionary:
	return _find_adapter(active_adapter_id)
func preview(rig_state: Dictionary = {}) -> Dictionary:
	var adapter := active_adapter()
	if adapter.is_empty(): return {"success": false, "errors": ["Prepare or open an LPC cutout rig first."]}
	return EvaluatorScript.evaluate(profile, adapter, rig_state, _canvas())
func set_bone_pose(bone_id: String, value: Dictionary) -> Dictionary:
	var adapter := active_adapter()
	if adapter.is_empty() or not (adapter.get("bones", {}) as Dictionary).has(bone_id): return {"success": false, "errors": ["Unknown LPC rig bone."]}
	var poses: Dictionary = (adapter.get("pose_overrides", {}) as Dictionary).duplicate(true); poses[bone_id] = value.duplicate(true); adapter["pose_overrides"] = poses
	return _replace_with_history("Set rigid bone pose", adapter)
func solve_hand_to_anchor(anchor_id: String, target: Variant, options: Dictionary = {}) -> Dictionary:
	var adapter := active_adapter()
	if adapter.is_empty(): return {"success": false, "errors": ["Prepare or open an LPC cutout rig first."]}
	var anchor: Dictionary = (adapter.get("anchors", {}) as Dictionary).get(anchor_id, {})
	var hand_id := str(anchor.get("bone_id", "")); var bones: Dictionary = adapter.get("bones", {})
	if hand_id.is_empty() or not bones.has(hand_id): return {"success": false, "errors": ["The selected anchor has no authored hand bone."]}
	var lower := str((bones[hand_id] as Dictionary).get("parent_id", "")); var upper := str((bones.get(lower, {}) as Dictionary).get("parent_id", ""))
	var solved := PoseSolverScript.solve_two_bone(adapter, upper, lower, hand_id, target, {"existing_state": adapter.get("pose_overrides", {}), "bend_positive": bool(options.get("bend_positive", not anchor_id.contains("right"))), "hand_rotation_degrees": options.get("hand_rotation_degrees", 0.0)})
	if not bool(solved.get("success", false)): return solved
	var poses: Dictionary = (adapter.get("pose_overrides", {}) as Dictionary).duplicate(true)
	for bone_id in (solved.get("bone_state", {}) as Dictionary): poses[bone_id] = solved.bone_state[bone_id]
	adapter["pose_overrides"] = poses
	var updated := _replace_with_history("Solve hand/weapon anchor", adapter); updated["solver"] = solved
	return updated
func repair_gap(rect: Rect2i, options: Dictionary = {}) -> Dictionary:
	var adapter := active_adapter()
	if adapter.is_empty(): return {"success": false, "errors": ["Prepare or open an LPC cutout rig first."]}
	if active_source == null or active_source.is_empty():
		var loaded := _load_source(adapter)
		if not bool(loaded.get("success", false)): return loaded
	var before := profile.duplicate(true); var repaired := PreparationScript.add_gap_patch(profile, active_adapter_id, active_source, rect, options)
	if not bool(repaired.get("success", false)): return repaired
	profile = (repaired.get("profile", {}) as Dictionary).duplicate(true); _set_state(); _record("Repair cutout gap", before, profile); changed.emit("Added project-owned gap patch")
	return repaired
func set_layer_strategy(instance_id: String, strategy: String, direction_id: String = "") -> Dictionary:
	var normalized := strategy.to_upper(); if normalized not in AdapterScript.STRATEGIES: return {"success": false, "errors": ["Unknown LPC layer strategy '%s'." % strategy]}
	var adapter := active_adapter()
	if not direction_id.is_empty() and not adapter.is_empty() and str(adapter.get("direction_id", "")) != direction_id: adapter = AdapterScript.find_for_layer(profile, instance_id, direction_id)
	var before := profile.duplicate(true); var overrides: Dictionary = (profile.get("rig_overrides", {}) as Dictionary).duplicate(true)
	overrides[instance_id] = {"representation": normalized, "adapter_instance_id": str(adapter.get("instance_id", "")), "source_fallback": "FRAME_NATIVE"}; profile["rig_overrides"] = overrides
	if not adapter.is_empty():
		var strategies: Dictionary = (adapter.get("layer_strategies", {}) as Dictionary).duplicate(true); strategies[instance_id] = normalized; adapter["layer_strategies"] = strategies; profile = PreparationScript._replace_adapter(profile, adapter)
	_set_state(); _record("Set LPC layer strategy", before, profile); changed.emit("Updated explicit LPC layer strategy")
	return {"success": true, "errors": [], "strategy": normalized}
func update_piece(piece_id: String, changes: Dictionary) -> Dictionary:
	var adapter := active_adapter()
	if adapter.is_empty(): return {"success": false, "errors": ["Prepare or open an LPC cutout rig first."]}
	var pieces: Array = (adapter.get("pieces", []) as Array).duplicate(true)
	var changed := false
	for index in range(pieces.size()):
		if not pieces[index] is Dictionary or str((pieces[index] as Dictionary).get("piece_id", "")) != piece_id: continue
		var piece: Dictionary = (pieces[index] as Dictionary).duplicate(true)
		for key in ["mask_rect", "bone_id", "z_group", "z_offset", "pivot", "slot_id", "strategy"]:
			if changes.has(key): piece[key] = changes[key]
		pieces[index] = piece; changed = true
	if not changed: return {"success": false, "errors": ["Unknown LPC cutout piece '%s'." % piece_id]}
	adapter["pieces"] = pieces
	return _replace_with_history("Adjust cutout piece", adapter)
func update_anchor(anchor_id: String, changes: Dictionary) -> Dictionary:
	var adapter := active_adapter()
	var anchors: Dictionary = (adapter.get("anchors", {}) as Dictionary).duplicate(true)
	if adapter.is_empty() or not anchors.has(anchor_id): return {"success": false, "errors": ["Unknown LPC rig anchor."]}
	var anchor: Dictionary = (anchors.get(anchor_id, {}) as Dictionary).duplicate(true)
	for key in ["bone_id", "position", "slot_id", "notes"]:
		if changes.has(key): anchor[key] = changes[key]
	anchors[anchor_id] = anchor; adapter["anchors"] = anchors
	return _replace_with_history("Adjust rig attachment anchor", adapter)
func update_bone(bone_id: String, changes: Dictionary) -> Dictionary:
	var adapter := active_adapter()
	var bones: Dictionary = (adapter.get("bones", {}) as Dictionary).duplicate(true)
	if adapter.is_empty() or not bones.has(bone_id): return {"success": false, "errors": ["Unknown LPC rig bone."]}
	var bone: Dictionary = (bones.get(bone_id, {}) as Dictionary).duplicate(true)
	for key in ["parent_id", "rest_position", "rest_rotation_degrees", "length"]:
		if changes.has(key): bone[key] = changes[key]
	bones[bone_id] = bone; adapter["bones"] = bones
	return _replace_with_history("Adjust rig rest bone", adapter)
func create_weighted_mesh(piece_id: String, options: Dictionary = {}) -> Dictionary:
	var adapter := active_adapter(); if adapter.is_empty(): return {"success": false, "errors": ["Prepare or open an LPC cutout rig first."]}
	var piece: Dictionary = {}; for raw in adapter.get("pieces", []): if raw is Dictionary and str((raw as Dictionary).get("piece_id", "")) == piece_id: piece = (raw as Dictionary).duplicate(true)
	if piece.is_empty(): return {"success": false, "errors": ["Unknown cutout piece '%s'." % piece_id]}
	var vertices: Array = options.get("rest_vertices", [[0, 0], [64, 0], [64, 64], [0, 64]])
	var mesh := WeightedMeshScript.create({"mesh_id": options.get("mesh_id", "skin:" + active_adapter_id + ":" + piece_id), "rig_adapter_id": active_adapter_id, "piece_id": piece_id, "derivative_id": piece.get("derivative_id", ""), "source_binding": adapter.get("source_binding", {}), "rest_vertices": vertices, "uvs": options.get("uvs", vertices), "triangle_indices": options.get("triangle_indices", [0, 1, 2, 0, 2, 3]), "max_influences": options.get("max_influences", 4), "control_state": options.get("control_state", {})})
	var initialized := WeightInitializerScript.nearest_bone_rigid(mesh, _bone_segments(adapter)); mesh = initialized
	var bones: Dictionary = adapter.get("bones", {}); var errors := WeightedMeshScript.validate(mesh, bones, AdapterScript.derivative_id_map(profile)); if not errors.is_empty(): return {"success": false, "errors": errors}
	var before := profile.duplicate(true); var meshes: Array = (profile.get("weighted_meshes", []) as Array).duplicate(true); meshes = meshes.filter(func(raw): return not (raw is Dictionary and str((raw as Dictionary).get("mesh_id", "")) == str(mesh.get("mesh_id", "")))); meshes.append(mesh); profile["weighted_meshes"] = meshes
	for index in range((adapter.get("pieces", []) as Array).size()):
		var raw = adapter.pieces[index]; if raw is Dictionary and str((raw as Dictionary).get("piece_id", "")) == piece_id: var changed_piece: Dictionary = raw.duplicate(true); changed_piece["strategy"] = "WEIGHTED_MESH"; adapter.pieces[index] = changed_piece
	profile = PreparationScript._replace_adapter(profile, adapter); _set_state(); _record("Create weighted LPC mesh", before, profile); changed.emit("Created weighted mesh with named nearest-bone initialization")
	return {"success": true, "errors": [], "mesh": mesh}
func paint_weights(mesh_id: String, bone_id: String, center: Variant, options: Dictionary = {}) -> Dictionary:
	var mesh := _find_weighted_mesh(mesh_id); if mesh.is_empty(): return {"success": false, "errors": ["Unknown LPC weighted mesh."]}
	var adapter := _find_adapter(str(mesh.get("rig_adapter_id", "")))
	if not (adapter.get("bones", {}) as Dictionary).has(bone_id): return {"success": false, "errors": ["Unknown LPC rig bone '%s'." % bone_id]}
	if str(options.get("mode", "")).to_upper() == "MIRROR" and not bool((adapter.get("mirror_policy", {}) as Dictionary).get("allowed", false)): return {"success": false, "errors": ["This direction-specific adapter has not approved mirrored weight painting."]}
	var painted := WeightPainterScript.apply_stroke(mesh, bone_id, center, options); if not bool(painted.get("success", false)): return painted
	var errors := WeightedMeshScript.validate(painted.mesh, adapter.get("bones", {}) as Dictionary, AdapterScript.derivative_id_map(profile)); if not errors.is_empty(): return {"success": false, "errors": errors}
	var before := profile.duplicate(true); profile = _replace_weighted_mesh(profile, painted.mesh); _record("Paint weighted mesh", before, profile); changed.emit("Applied atomic topology-aware weight stroke")
	return painted
func set_cage(mesh_id: String, cage: Dictionary) -> Dictionary:
	var mesh := _find_weighted_mesh(mesh_id); var errors := CageScript.validate(cage); if mesh.is_empty() or not errors.is_empty(): return {"success": false, "errors": ["Unknown LPC weighted mesh."] if mesh.is_empty() else errors}
	var state := WeightedMeshScript.default_control_state(mesh.get("control_state", {})); state["cage"] = cage.duplicate(true); mesh["control_state"] = state
	var before := profile.duplicate(true); profile = _replace_weighted_mesh(profile, mesh); _record("Set true cage deformation", before, profile); changed.emit("Updated ordered mean-value cage")
	return {"success": true, "errors": [], "mesh": mesh}
func set_weighted_evaluation_order(mesh_id: String, order: Array) -> Dictionary:
	var mesh := _find_weighted_mesh(mesh_id); if mesh.is_empty(): return {"success": false, "errors": ["Unknown LPC weighted mesh."]}
	var expected := WeightedMeshScript.DEFAULT_ORDER.duplicate(); var normalized: Array = []; for stage in order: if str(stage) in expected and str(stage) not in normalized: normalized.append(str(stage))
	for stage in expected: if stage not in normalized: normalized.append(stage)
	var state := WeightedMeshScript.default_control_state(mesh.get("control_state", {})); state["evaluation_order"] = normalized; mesh["control_state"] = state
	var before := profile.duplicate(true); profile = _replace_weighted_mesh(profile, mesh); _record("Set weighted evaluation order", before, profile); changed.emit("Set explicit weighted deformation evaluation order")
	return {"success": true, "errors": [], "mesh": mesh}
func set_weighted_controls(mesh_id: String, changes: Dictionary) -> Dictionary:
	var mesh := _find_weighted_mesh(mesh_id); if mesh.is_empty(): return {"success": false, "errors": ["Unknown LPC weighted mesh."]}
	var state := WeightedMeshScript.default_control_state(mesh.get("control_state", {}))
	for key in ["cage", "lattice", "pins", "soft_drags", "vertex_offsets", "evaluation_order"]:
		if changes.has(key): state[key] = changes[key]
	mesh["control_state"] = state
	var adapter := _find_adapter(str(mesh.get("rig_adapter_id", ""))); var errors := WeightedMeshScript.validate(mesh, adapter.get("bones", {}) as Dictionary, AdapterScript.derivative_id_map(profile))
	if not errors.is_empty(): return {"success": false, "errors": errors}
	var before := profile.duplicate(true); profile = _replace_weighted_mesh(profile, mesh); _record("Update weighted deformation controls", before, profile); changed.emit("Updated non-destructive cage, pins, lattice, soft drag, or direct offsets")
	return {"success": true, "errors": [], "mesh": mesh}
func initialize_weights(mesh_id: String, method: String, options: Dictionary = {}) -> Dictionary:
	var mesh := _find_weighted_mesh(mesh_id); var adapter := _find_adapter(str(mesh.get("rig_adapter_id", "")))
	if mesh.is_empty() or adapter.is_empty(): return {"success": false, "errors": ["Open a prepared LPC rig and weighted mesh first."]}
	var initialized: Variant
	match method.to_lower():
		"nearest_bone_rigid": initialized = WeightInitializerScript.nearest_bone_rigid(mesh, _bone_segments(adapter))
		"distance_to_segment": initialized = WeightInitializerScript.distance_to_segment(mesh, _bone_segments(adapter), int(options.get("max_influences", mesh.get("max_influences", 4))), float(options.get("falloff_power", 2.0)))
		_: return {"success": false, "errors": ["Choose nearest_bone_rigid, distance_to_segment, or shared_topology_transfer."]}
	var next_mesh: Dictionary = initialized as Dictionary
	var errors := WeightedMeshScript.validate(next_mesh, adapter.get("bones", {}) as Dictionary, AdapterScript.derivative_id_map(profile)); if not errors.is_empty(): return {"success": false, "errors": errors}
	var before := profile.duplicate(true); profile = _replace_weighted_mesh(profile, next_mesh); _record("Initialize weighted mesh", before, profile); changed.emit("Initialized weights using " + method)
	return {"success": true, "errors": [], "mesh": next_mesh}
func transfer_shared_weights(target_mesh_id: String, source_mesh_id: String) -> Dictionary:
	var target := _find_weighted_mesh(target_mesh_id); var source := _find_weighted_mesh(source_mesh_id)
	if target.is_empty() or source.is_empty(): return {"success": false, "errors": ["Choose an existing source and target weighted mesh."]}
	var transferred := WeightInitializerScript.transfer_shared_topology(target, source)
	if not bool(transferred.get("success", false)): return transferred
	var adapter := _find_adapter(str(target.get("rig_adapter_id", ""))); var errors := WeightedMeshScript.validate(transferred.mesh, adapter.get("bones", {}) as Dictionary, AdapterScript.derivative_id_map(profile)); if not errors.is_empty(): return {"success": false, "errors": errors}
	var before := profile.duplicate(true); profile = _replace_weighted_mesh(profile, transferred.mesh); _record("Transfer shared topology weights", before, profile); changed.emit("Transferred validated shared-topology weights")
	return transferred
func weighted_influences(mesh_id: String, vertex_index: int) -> Array:
	var mesh := _find_weighted_mesh(mesh_id)
	return WeightPainterScript.influences(mesh, vertex_index) if not mesh.is_empty() else []
func enable_eight_directions(options: Dictionary = {}) -> Dictionary:
	var before := profile.duplicate(true); var result := DirectionAuthoringScript.enable_eight_direction(profile, options)
	if not bool(result.get("success", false)): return result
	profile = (result.get("profile", {}) as Dictionary).duplicate(true); _record("Enable authored eight directions", before, profile); changed.emit("Enabled explicit eight-direction LPC authoring")
	return result
func author_direction(direction_id: String, representation: String, options: Dictionary = {}) -> Dictionary:
	var values := options.duplicate(true)
	if str(representation).to_upper() == "RIGGED" and not values.has("adapter_instance_id"): values["adapter_instance_id"] = active_adapter_id
	var before := profile.duplicate(true); var result := DirectionAuthoringScript.author(profile, direction_id, representation, values)
	if not bool(result.get("success", false)): return result
	profile = (result.get("profile", {}) as Dictionary).duplicate(true); _record("Author %s direction" % direction_id, before, profile); changed.emit("Recorded explicit LPC direction representation")
	return result
func undo() -> bool:
	if _undo.is_empty(): return false
	var command: Dictionary = _undo.pop_back(); _redo.append(command); profile = command.before.duplicate(true); _set_state(); changed.emit("Undid rig command"); return true
func redo() -> bool:
	if _redo.is_empty(): return false
	var command: Dictionary = _redo.pop_back(); _undo.append(command); profile = command.after.duplicate(true); _set_state(); changed.emit("Redid rig command"); return true
func save() -> Dictionary:
	if project_path.is_empty() or manifest.is_empty(): return {"success": false, "errors": ["Bind an LPC project before saving cutout-rig state."]}
	var saved := ProjectStoreScript.save(project_path, manifest, profile)
	if bool(saved.get("success", false)): manifest = saved.manifest.duplicate(true)
	return saved
func autosave() -> Dictionary:
	return ProjectStoreScript.autosave(project_path, manifest, profile) if not project_path.is_empty() and not manifest.is_empty() else {"success": false, "errors": ["Bind an LPC project before autosaving cutout-rig state."]}
func _replace_with_history(description: String, adapter: Dictionary) -> Dictionary:
	var errors := AdapterScript.validate(adapter, AdapterScript.derivative_id_map(profile)); if not errors.is_empty(): return {"success": false, "errors": errors}
	var before := profile.duplicate(true); profile = PreparationScript._replace_adapter(profile, adapter); _set_state(); _record(description, before, profile); changed.emit(description)
	return {"success": true, "errors": [], "adapter": adapter}
func _record(description: String, before: Dictionary, after: Dictionary) -> void:
	_undo.append({"description": description, "before": before.duplicate(true), "after": after.duplicate(true)}); _redo.clear()
func _find_adapter(adapter_id: String) -> Dictionary:
	for raw in profile.get("rig_adapters", []): if raw is Dictionary and str((raw as Dictionary).get("instance_id", "")) == adapter_id: return (raw as Dictionary).duplicate(true)
	return {}
func _find_weighted_mesh(mesh_id: String) -> Dictionary:
	for raw in profile.get("weighted_meshes", []): if raw is Dictionary and str((raw as Dictionary).get("mesh_id", "")) == mesh_id: return (raw as Dictionary).duplicate(true)
	return {}
func _replace_weighted_mesh(next_profile: Dictionary, mesh: Dictionary) -> Dictionary:
	var next := next_profile.duplicate(true); var meshes: Array = (next.get("weighted_meshes", []) as Array).duplicate(true)
	for index in range(meshes.size()): if meshes[index] is Dictionary and str((meshes[index] as Dictionary).get("mesh_id", "")) == str(mesh.get("mesh_id", "")): meshes[index] = mesh.duplicate(true)
	next["weighted_meshes"] = meshes; return next
func _bone_segments(adapter: Dictionary) -> Array:
	var transforms := EvaluatorScript.bone_transforms(adapter, {}); var output: Array = []
	for bone_id in (adapter.get("bones", {}) as Dictionary):
		var bone: Dictionary = adapter.bones[bone_id]; var transform: Transform2D = transforms.get("rest", {}).get(bone_id, Transform2D.IDENTITY); var head := transform.origin; var tail := transform * Vector2(float(bone.get("length", 1.0)), 0)
		output.append({"bone_id": str(bone_id), "head": [head.x, head.y], "tail": [tail.x, tail.y]})
	return output
func _load_source(adapter: Dictionary) -> Dictionary:
	var binding: Dictionary = adapter.get("source_binding", {}); var pixels = PixelModelScript.new(); var ref: Dictionary = binding.get("source_frame_reference", {})
	var loaded := pixels.open_native_frame(catalog, profile, str(binding.get("source_instance_id", "")), str(ref.get("animation_id", "walk")), str(ref.get("direction_id", "down")), int(ref.get("logical_frame_index", 0)))
	if bool(loaded.get("success", false)): active_source = pixels.image.duplicate()
	return loaded
func _set_state() -> void: profile["rig_workspace_state"] = {"active_adapter_id": active_adapter_id}
func _canvas() -> Vector2i:
	var values: Dictionary = profile.get("native_canvas", {}); return Vector2i(int(values.get("width", 64)), int(values.get("height", 64)))
