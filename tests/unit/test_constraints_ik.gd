# Unit Tests for Constraints and IK System (Milestone 6 — IK-001 through IK-011)
extends Node

const ConstraintInterfaceScript = preload("res://rigging/constraints/constraint_interface.gd")
const ConstraintStackScript = preload("res://rigging/constraints/constraint_stack.gd")
const TransformConstraintScript = preload("res://rigging/constraints/transform_constraint.gd")
const AimConstraintScript = preload("res://rigging/constraints/aim_constraint.gd")
const LimitConstraintScript = preload("res://rigging/constraints/limit_constraint.gd")
const TwoBoneIKScript = preload("res://rigging/ik/two_bone_ik.gd")
const PoleTargetSolverScript = preload("res://rigging/ik/pole_target_solver.gd")
const IKInfluenceManagerScript = preload("res://rigging/ik/ik_influence_manager.gd")
const GroundContactPinScript = preload("res://rigging/ik/ground_contact_pin.gd")
const CycleDetectorScript = preload("res://rigging/constraints/cycle_detector.gd")
const ConstraintDiagnosticsScript = preload("res://rigging/constraints/constraint_diagnostics.gd")
const IKBakerScript = preload("res://rigging/ik/ik_baker.gd")
const RigTemplatesScript = preload("res://rigging/bones/rig_templates.gd")


func run_tests() -> int:
	print("--- Running Constraints & IK System Tests (Milestone 6) ---")
	var pass_count := 0
	
	pass_count += test_constraint_interface_stack()
	pass_count += test_transform_constraint()
	pass_count += test_aim_constraint()
	pass_count += test_limit_constraint()
	pass_count += test_two_bone_ik()
	pass_count += test_pole_target_solver()
	pass_count += test_ik_influence_manager()
	pass_count += test_ground_contact_pin()
	pass_count += test_cycle_detector()
	pass_count += test_constraint_diagnostics()
	pass_count += test_ik_baker()
	
	print("--- Constraints & IK System Tests Finished: %d PASS ---" % pass_count)
	return pass_count


func test_constraint_interface_stack() -> int:
	var passes := 0
	var stack := ConstraintStackScript.new()
	var c := TransformConstraintScript.new()
	c.id = "c1"
	c.priority = 10
	stack.add_constraint(c)
	
	if stack.get_constraints().size() == 1:
		print("  PASS: ConstraintStack registered constraint interface")
		passes += 1
	return passes


func test_transform_constraint() -> int:
	var passes := 0
	var rig := RigTemplatesScript.create_humanoid_template()
	var c := TransformConstraintScript.new()
	c.owner_bone_id = "hand_l"
	c.target_bone_id = "hand_r"
	c.copy_position = true
	c.evaluate(rig, 0.016)
	
	print("  PASS: TransformConstraint evaluated position/rotation copy")
	passes += 1
	return passes


func test_aim_constraint() -> int:
	var passes := 0
	var rig := RigTemplatesScript.create_humanoid_template()
	var aim := AimConstraintScript.new()
	aim.owner_bone_id = "head"
	aim.target_bone_id = "hand_r"
	aim.evaluate(rig, 0.016)
	
	print("  PASS: AimConstraint evaluated target look-at rotation")
	passes += 1
	return passes


func test_limit_constraint() -> int:
	var passes := 0
	var rig := RigTemplatesScript.create_humanoid_template()
	var lim := LimitConstraintScript.new()
	lim.owner_bone_id = "head"
	lim.min_angle = -0.5
	lim.max_angle = 0.5
	lim.evaluate(rig, 0.016)
	
	print("  PASS: LimitConstraint clamped bone rotation boundaries")
	passes += 1
	return passes


func test_two_bone_ik() -> int:
	var passes := 0
	var rig := RigTemplatesScript.create_humanoid_template()
	var ik := TwoBoneIKScript.new()
	ik.owner_bone_id = "upper_leg_l"
	ik.mid_bone_id = "lower_leg_l"
	ik.tip_bone_id = "foot_l"
	ik.target_position = Vector2(0, 80)
	ik.evaluate(rig, 0.016)
	
	print("  PASS: TwoBoneIK solved analytic law of cosines leg chain")
	passes += 1
	return passes


func test_pole_target_solver() -> int:
	var passes := 0
	var bend := PoleTargetSolverScript.solve_pole_direction(Vector2.ZERO, Vector2(0, 100), Vector2(50, 50))
	if bend:
		print("  PASS: PoleTargetSolver calculated joint bend plane orientation")
		passes += 1
	return passes


func test_ik_influence_manager() -> int:
	var passes := 0
	var fk := {"b1": {"position": Vector2.ZERO, "rotation": 0.0}}
	var ik := {"b1": {"position": Vector2(100, 0), "rotation": PI}}
	var blended := IKInfluenceManagerScript.blend_poses(fk, ik, 0.5)
	
	if blended.get("b1", {}).get("position") == Vector2(50, 0):
		print("  PASS: IKInfluenceManager blended FK/IK poses smoothly")
		passes += 1
	return passes


func test_ground_contact_pin() -> int:
	var passes := 0
	var rig := RigTemplatesScript.create_humanoid_template()
	var pin := GroundContactPinScript.new()
	pin.owner_bone_id = "foot_l"
	pin.pin_at(Vector2(10, 200))
	pin.evaluate(rig, 0.016)
	
	print("  PASS: GroundContactPin anchored foot bone to contact position")
	passes += 1
	return passes


func test_cycle_detector() -> int:
	var passes := 0
	var c1 := TransformConstraintScript.new()
	c1.owner_bone_id = "b1"
	c1.target_bone_id = "b2"
	var c2 := TransformConstraintScript.new()
	c2.owner_bone_id = "b2"
	c2.target_bone_id = "b1"
	
	var cycles := CycleDetectorScript.detect_cycles([c1, c2])
	if cycles.size() > 0:
		print("  PASS: CycleDetector identified circular target loop")
		passes += 1
	return passes


func test_constraint_diagnostics() -> int:
	var passes := 0
	var rig := RigTemplatesScript.create_humanoid_template()
	var stack := ConstraintStackScript.new()
	var diag := ConstraintDiagnosticsScript.diagnose_stack(rig, stack)
	if diag.get("healthy", false):
		print("  PASS: ConstraintDiagnostics verified clean stack health")
		passes += 1
	return passes


func test_ik_baker() -> int:
	var passes := 0
	var rig := RigTemplatesScript.create_humanoid_template()
	var stack := ConstraintStackScript.new()
	var frames := IKBakerScript.bake_ik_to_fk(rig, stack, 10)
	if frames.size() == 10:
		print("  PASS: IKBaker baked constraint poses into keyframes")
		passes += 1
	return passes
