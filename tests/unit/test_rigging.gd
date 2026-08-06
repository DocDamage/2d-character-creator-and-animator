# Unit Tests for Rigging System (Milestone 5 — RIG-001 through RIG-012)
extends Node

const BoneSchemaScript = preload("res://rigging/bones/bone_schema.gd")
const SlotSchemaScript = preload("res://rigging/slots/slot_schema.gd")
const RigSchemaScript = preload("res://rigging/bones/rig_schema.gd")
const BoneManagerScript = preload("res://rigging/bones/bone_manager.gd")
const HierarchyPanelScript = preload("res://rigging/bones/hierarchy_panel.gd")
const RestPoseManagerScript = preload("res://rigging/bones/rest_pose_manager.gd")
const HierarchyOperationsScript = preload("res://rigging/bones/hierarchy_operations.gd")
const BonePropertiesScript = preload("res://rigging/bones/bone_properties.gd")
const MirrorHierarchyScript = preload("res://rigging/bones/mirror_hierarchy.gd")
const SlotManagerScript = preload("res://rigging/slots/slot_manager.gd")
const TransformInheritanceScript = preload("res://rigging/bones/transform_inheritance.gd")
const RigTemplatesScript = preload("res://rigging/bones/rig_templates.gd")
const RigValidatorScript = preload("res://rigging/bones/rig_validator.gd")
const RigPersistenceScript = preload("res://rigging/bones/rig_persistence.gd")


func run_tests() -> int:
	print("--- Running Rigging System Tests (Milestone 5) ---")
	var pass_count := 0
	
	pass_count += test_rig_schemas()
	pass_count += test_bone_creation_transform()
	pass_count += test_hierarchy_panel()
	pass_count += test_rest_pose()
	pass_count += test_reparent_reorder()
	pass_count += test_bone_properties()
	pass_count += test_mirror_hierarchy()
	pass_count += test_slot_authoring()
	pass_count += test_transform_inheritance()
	pass_count += test_rig_templates()
	pass_count += test_rig_validator()
	pass_count += test_rig_persistence()
	
	print("--- Rigging System Tests Finished: %d PASS ---" % pass_count)
	return pass_count


func test_rig_schemas() -> int:
	var passes := 0
	var b_def := BoneSchemaScript.create_default_bone("b1", "RootBone")
	if b_def.get("id") == "b1":
		print("  PASS: BoneSchema created valid default bone dictionary")
		passes += 1
		
	var s_def := SlotSchemaScript.create_default_slot("s1", "HeadSlot", "b1")
	if s_def.get("bone_id") == "b1":
		print("  PASS: SlotSchema created valid default slot dictionary")
		passes += 1
		
	var rig := RigSchemaScript.create_empty_rig("r1", "TestRig")
	if rig.get("id") == "r1":
		print("  PASS: RigSchema created valid empty rig dictionary")
		passes += 1
		
	return passes


func test_bone_creation_transform() -> int:
	var passes := 0
	var rig := RigSchemaScript.create_empty_rig("r1", "Test")
	var bm := BoneManagerScript.new()
	bm.initialize(rig)
	
	var b1 := bm.add_bone("Root", "", 50.0)
	var b2 := bm.add_bone("Child", b1.get("id", ""), 30.0)
	
	if rig.get("bones", {}).size() == 2:
		print("  PASS: BoneManager added bones to rig correctly")
		passes += 1
		
	bm.set_local_transform(b1.get("id", ""), Vector2(100, 50), 0.0, Vector2.ONE)
	var global_tf := bm.get_global_transform(b2.get("id", ""))
	if global_tf.origin == Vector2(100, 50):
		print("  PASS: BoneManager computed global transform hierarchy")
		passes += 1
		
	return passes


func test_hierarchy_panel() -> int:
	var passes := 0
	var hp := HierarchyPanelScript.new()
	hp.select_node("node1")
	if hp.get_selected_ids() == ["node1"]:
		print("  PASS: HierarchyPanel selected node correctly")
		passes += 1
	return passes


func test_rest_pose() -> int:
	var passes := 0
	var rig := RigSchemaScript.create_empty_rig("r1", "Test")
	var bm := BoneManagerScript.new()
	bm.initialize(rig)
	var b1 := bm.add_bone("Bone1", "", 50.0)
	
	var rest := RestPoseManagerScript.capture_rest_pose(rig)
	if rest.has(b1.get("id", "")):
		print("  PASS: RestPoseManager captured bind pose correctly")
		passes += 1
		
	return passes


func test_reparent_reorder() -> int:
	var passes := 0
	var rig := RigSchemaScript.create_empty_rig("r1", "Test")
	var bm := BoneManagerScript.new()
	bm.initialize(rig)
	var b1 := bm.add_bone("Root", "", 50.0)
	var b2 := bm.add_bone("Child1", "", 30.0)
	
	var res := HierarchyOperationsScript.reparent_bone(rig, b2.get("id", ""), b1.get("id", ""), true)
	if res and b2.get("parent_id", "") == b1.get("id", ""):
		print("  PASS: HierarchyOperations reparented bone with world lock")
		passes += 1
		
	return passes


func test_bone_properties() -> int:
	var passes := 0
	var rig := RigSchemaScript.create_empty_rig("r1", "Test")
	var bm := BoneManagerScript.new()
	bm.initialize(rig)
	var b1 := bm.add_bone("Bone1", "", 50.0)
	
	BonePropertiesScript.set_bone_color(rig, b1.get("id", ""), Color.RED)
	if rig["bones"][b1.get("id", "")]["color"] == Color.RED:
		print("  PASS: BoneProperties updated bone color tag")
		passes += 1
		
	return passes


func test_mirror_hierarchy() -> int:
	var passes := 0
	var name_m := MirrorHierarchyScript.mirror_name("arm_l")
	if name_m == "arm_r":
		print("  PASS: MirrorHierarchy mirrored bone name convention correctly")
		passes += 1
	return passes


func test_slot_authoring() -> int:
	var passes := 0
	var rig := RigSchemaScript.create_empty_rig("r1", "Test")
	var sm := SlotManagerScript.new()
	sm.initialize(rig)
	var slot := sm.add_slot("HeadSlot", "bone_1")
	if rig.get("slots", {}).size() == 1:
		print("  PASS: SlotManager added slot attachment binding")
		passes += 1
	return passes


func test_transform_inheritance() -> int:
	var passes := 0
	var tf := TransformInheritanceScript.compute_inherited_transform(Transform2D.IDENTITY, Vector2(10, 20), 0.0, Vector2.ONE, true, true, true)
	if tf.origin == Vector2(10, 20):
		print("  PASS: TransformInheritance resolved channel inheritance correctly")
		passes += 1
	var rig := RigSchemaScript.create_empty_rig("inheritance_rig", "Inheritance")
	var manager := BoneManagerScript.new()
	manager.initialize(rig)
	var parent := manager.add_bone("Parent")
	var child := manager.add_bone("Child", str(parent.get("id", "")))
	manager.set_local_transform(str(parent.get("id", "")), Vector2(20, 30), PI / 2.0, Vector2(2, 2))
	manager.set_local_transform(str(child.get("id", "")), Vector2(4, 5), 0.25, Vector2(1.5, 0.75))
	TransformInheritanceScript.set_inheritance_flags(rig, str(child.get("id", "")), false, false, false)
	var independent := manager.get_global_transform(str(child.get("id", "")))
	if independent.origin.is_equal_approx(Vector2(4, 5)) and is_equal_approx(independent.get_rotation(), 0.25) and independent.get_scale().is_equal_approx(Vector2(1.5, 0.75)):
		print("  PASS: BoneManager honours disabled position, rotation, and scale inheritance")
		passes += 1
	TransformInheritanceScript.set_inheritance_flags(rig, str(child.get("id", "")), true, false, false)
	var position_only := manager.get_global_transform(str(child.get("id", "")))
	if position_only.origin.is_equal_approx(Vector2(10, 38)) and is_equal_approx(position_only.get_rotation(), 0.25) and position_only.get_scale().is_equal_approx(Vector2(1.5, 0.75)):
		print("  PASS: BoneManager applies selective transform inheritance without leaking rotation or scale")
		passes += 1
	return passes


func test_rig_templates() -> int:
	var passes := 0
	var humanoid := RigTemplatesScript.create_humanoid_template()
	if humanoid.get("bones", {}).size() > 10:
		print("  PASS: RigTemplates created standard humanoid skeleton")
		passes += 1
	return passes


func test_rig_validator() -> int:
	var passes := 0
	var rig := RigTemplatesScript.create_humanoid_template()
	var diag := RigValidatorScript.validate(rig)
	if diag.get("valid", false):
		print("  PASS: RigValidator confirmed humanoid rig integrity")
		passes += 1
	return passes


func test_rig_persistence() -> int:
	var passes := 0
	var rig := RigTemplatesScript.create_humanoid_template()
	var json_str := RigPersistenceScript.serialize_rig(rig)
	var loaded := RigPersistenceScript.deserialize_rig(json_str)
	if loaded.get("id") == rig.get("id"):
		print("  PASS: RigPersistence serialized and deserialized rig roundtrip")
		passes += 1
	return passes
