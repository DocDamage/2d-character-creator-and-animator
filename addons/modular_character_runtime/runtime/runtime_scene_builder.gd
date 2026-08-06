# RuntimeSceneBuilder -- Builds portable visual, animation, marker, and collision nodes from mapped data.
extends RefCounted


func build(owner: Node2D, mapping: Dictionary, add_mesh: Callable) -> Dictionary:
	_clear_generated(owner)
	var report := {"animations": 0, "animation_tree": false, "meshes": 0, "sprites": 0, "markers": 0, "collision_shapes": 0, "weapons": (mapping.get("weapons", []) as Array).size()}
	var player := AnimationPlayer.new()
	player.name = "RuntimeAnimationPlayer"
	player.add_to_group("modular_runtime_generated")
	owner.add_child(player)
	var library := AnimationLibrary.new()
	for clip_id in mapping.get("animation_library", {}) as Dictionary:
		var record: Dictionary = mapping.animation_library[clip_id]
		var animation := Animation.new()
		animation.length = maxf(0.001, float(record.get("length", 0.0)))
		animation.loop_mode = Animation.LOOP_LINEAR if bool(record.get("loop", true)) else Animation.LOOP_NONE
		library.add_animation(str(clip_id), animation)
		report["animations"] += 1
	player.add_animation_library("", library)
	var tree := AnimationTree.new()
	tree.name = "RuntimeAnimationTree"
	tree.tree_root = AnimationNodeStateMachine.new()
	tree.anim_player = owner.get_path_to(player)
	tree.add_to_group("modular_runtime_generated")
	owner.add_child(tree)
	report["animation_tree"] = true
	for mesh in mapping.get("meshes", []) as Array:
		var node = add_mesh.call(mesh as Dictionary)
		if node != null: node.add_to_group("modular_runtime_generated"); report["meshes"] += 1
	for sprite in mapping.get("sprites", []) as Array:
		var record := sprite as Dictionary
		var node := Sprite2D.new()
		node.name = str(record.get("sprite_id", "RuntimeSprite"))
		node.position = _vector(record.get("position", [0.0, 0.0]))
		node.add_to_group("modular_runtime_generated")
		owner.add_child(node)
		report["sprites"] += 1
	for marker in mapping.get("markers", []) as Array:
		var record := marker as Dictionary
		var node := Marker2D.new()
		node.name = str(record.get("marker_id", record.get("point_id", "RuntimeMarker")))
		node.position = _vector(record.get("position", record.get("local_position", [0.0, 0.0])))
		node.add_to_group("modular_runtime_generated")
		owner.add_child(node)
		report["markers"] += 1
	for collision in mapping.get("collision_shapes", []) as Array:
		var node := _collision_node(collision as Dictionary)
		if node != null: node.add_to_group("modular_runtime_generated"); owner.add_child(node); report["collision_shapes"] += 1
	return report


func _clear_generated(owner: Node2D) -> void:
	for child in owner.get_children():
		if child.is_in_group("modular_runtime_generated"):
			owner.remove_child(child)
			child.free()


func _collision_node(record: Dictionary) -> Area2D:
	var area := Area2D.new()
	area.name = str(record.get("shape_id", "RuntimeArea"))
	area.position = _vector(record.get("position", [0.0, 0.0]))
	var shape_node := CollisionShape2D.new()
	var shape_type := str(record.get("shape_type", "rectangle"))
	if shape_type == "circle":
		var circle := CircleShape2D.new(); circle.radius = float(record.get("radius", 8.0)); shape_node.shape = circle
	else:
		var rectangle := RectangleShape2D.new(); rectangle.size = _vector(record.get("size", [16.0, 16.0])); shape_node.shape = rectangle
	area.add_child(shape_node)
	return area


func _vector(value: Variant) -> Vector2:
	if value is Vector2: return value
	if value is Array and value.size() >= 2: return Vector2(float(value[0]), float(value[1]))
	return Vector2.ZERO
