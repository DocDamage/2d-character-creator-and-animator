# Unit Tests for Curves & Onion Skinning (Milestone 8 -- CRV-001 through CRV-007, ONI-001 through ONI-004)
# QA-CRV-001: Comprehensive test suite for curve interpolation, presets, simplification, and onion skins.
extends Node

const KeyframeDataScript = preload("res://animation/keys/keyframe_schema.gd")
const LinearSteppedEvaluatorScript = preload("res://animation/curves/linear_stepped_evaluator.gd")
const SmoothCubicEvaluatorScript = preload("res://animation/curves/smooth_cubic_evaluator.gd")
const BezierEvaluatorScript = preload("res://animation/curves/bezier_evaluator.gd")
const AngleInterpolatorScript = preload("res://animation/curves/angle_interpolator.gd")
const CurveEditorModelScript = preload("res://animation/curves/curve_editor_model.gd")
const CurvePresetsScript = preload("res://animation/curves/curve_presets.gd")
const CurveSimplifierScript = preload("res://animation/curves/curve_simplifier.gd")
const AdjacentGhostPipelineScript = preload("res://animation/onion_skin/adjacent_ghost_pipeline.gd")
const KeyPinnedGhostManagerScript = preload("res://animation/onion_skin/key_pinned_ghost_manager.gd")
const InteractiveOnionControllerScript = preload("res://animation/onion_skin/interactive_onion_controller.gd")
const OnionRenderStyleScript = preload("res://animation/onion_skin/onion_render_style.gd")


func run_tests() -> int:
	print("--- Running Curves & Onion Skinning Tests (Milestone 8) ---")
	var passes := 0

	passes += test_linear_stepped_evaluator()
	passes += test_smooth_cubic_evaluator()
	passes += test_bezier_evaluator()
	passes += test_angle_interpolator()
	passes += test_curve_editor_model()
	passes += test_curve_presets()
	passes += test_curve_simplifier()
	passes += test_adjacent_ghost_pipeline()
	passes += test_key_pinned_ghost_manager()
	passes += test_interactive_onion_controller()
	passes += test_onion_render_style()

	print("--- Curves & Onion Skinning Tests Finished: %d PASS ---" % passes)
	return passes


func test_linear_stepped_evaluator() -> int:
	var p := 0
	var k1: RefCounted = KeyframeDataScript.new("k1", 0.0, 10.0)
	var k2: RefCounted = KeyframeDataScript.new("k2", 2.0, 30.0)

	var val_step: Variant = LinearSteppedEvaluatorScript.evaluate_stepped(k1, k2, 1.0)
	if float(val_step) == 10.0:
		print("  PASS: CRV-001 Stepped evaluation holds start value")
		p += 1

	var val_lin: Variant = LinearSteppedEvaluatorScript.evaluate_linear(k1, k2, 1.0)
	if float(val_lin) == 20.0:
		print("  PASS: CRV-001 Linear evaluation interpolates midpoint")
		p += 1

	var v1 := Vector2(0, 0)
	var v2 := Vector2(10, 20)
	var v_mid: Vector2 = LinearSteppedEvaluatorScript.interpolate_values(v1, v2, 0.5) as Vector2
	if v_mid.distance_to(Vector2(5, 10)) < 0.001:
		print("  PASS: CRV-001 Vector2 linear interpolation")
		p += 1

	return p


func test_smooth_cubic_evaluator() -> int:
	var p := 0
	var k1: RefCounted = KeyframeDataScript.new("k1", 0.0, 0.0)
	var k2: RefCounted = KeyframeDataScript.new("k2", 1.0, 100.0)

	var smooth_val: float = float(SmoothCubicEvaluatorScript.evaluate_smooth(k1, k2, 0.5))
	if absf(smooth_val - 50.0) < 5.0:
		print("  PASS: CRV-002 Smooth cubic evaluation evaluates smooth mid-point")
		p += 1

	var h_val: float = SmoothCubicEvaluatorScript.cubic_hermite(0.0, 1.0, 0.0, 0.0, 0.5)
	if absf(h_val - 0.5) < 0.01:
		print("  PASS: CRV-002 Hermite cubic curve midpoint")
		p += 1

	return p


func test_bezier_evaluator() -> int:
	var p := 0
	var y_mid: float = BezierEvaluatorScript.evaluate_bezier_1d(0.5, Vector2(0.25, 0.1), Vector2(-0.25, 0.9))
	if absf(y_mid - 0.5) < 0.1:
		print("  PASS: CRV-003 Cubic Bézier curve 1D evaluation")
		p += 1

	var k1: RefCounted = KeyframeDataScript.new("k1", 0.0, 0.0)
	var k2: RefCounted = KeyframeDataScript.new("k2", 2.0, 10.0)
	var val: float = float(BezierEvaluatorScript.evaluate_bezier_keys(k1, k2, 1.0))
	if absf(val - 5.0) < 1.0:
		print("  PASS: CRV-003 Cubic Bézier keyframe evaluation")
		p += 1

	return p


func test_angle_interpolator() -> int:
	var p := 0
	var res_deg: float = AngleInterpolatorScript.interpolate_degrees(170.0, -170.0, 0.5, AngleInterpolatorScript.Mode.SHORTEST_PATH)
	if absf(AngleInterpolatorScript.normalize_degrees(res_deg) - 180.0) < 0.1 or absf(AngleInterpolatorScript.normalize_degrees(res_deg) - (-180.0)) < 0.1:
		print("  PASS: CRV-004 Shortest path angle interpolation")
		p += 1

	var cont_deg: float = AngleInterpolatorScript.interpolate_degrees(0.0, 360.0, 0.5, AngleInterpolatorScript.Mode.CONTINUOUS)
	if absf(cont_deg - 180.0) < 0.1:
		print("  PASS: CRV-004 Continuous angle interpolation")
		p += 1

	return p


func test_curve_editor_model() -> int:
	var p := 0
	var model = CurveEditorModelScript.new()
	model.select_key("k1")
	if model.selected_key_ids.has("k1"):
		print("  PASS: CRV-005 CurveEditorModel key selection")
		p += 1

	model.pan(Vector2(50, 0))
	if model.pan_offset == Vector2(50, 0):
		print("  PASS: CRV-005 CurveEditorModel viewport pan")
		p += 1

	return p


func test_curve_presets() -> int:
	var p := 0
	var names: Array[String] = CurvePresetsScript.get_preset_names()
	if names.size() >= 8:
		print("  PASS: CRV-006 Preset easing library contains standard curves")
		p += 1

	var ease_in_val: float = CurvePresetsScript.evaluate_preset(CurvePresetsScript.PresetType.EASE_IN, 0.5)
	if absf(ease_in_val - 0.125) < 0.001:
		print("  PASS: CRV-006 Ease-in preset evaluation")
		p += 1

	return p


func test_curve_simplifier() -> int:
	var p := 0
	var k1: RefCounted = KeyframeDataScript.new("k1", 0.0, 0.0)
	var k2: RefCounted = KeyframeDataScript.new("k2", 1.0, 5.0)
	var k3: RefCounted = KeyframeDataScript.new("k3", 2.0, 10.0)

	var keys: Array = [k1, k2, k3]
	var simplified: Array = CurveSimplifierScript.simplify_keyframes(keys, 0.1)
	if simplified.size() == 2:
		print("  PASS: CRV-007 Ramer-Douglas-Peucker simplifies redundant collinear keys")
		p += 1

	var baked: Array = CurveSimplifierScript.bake_curve(k1, k3, 0.5)
	if baked.size() >= 4:
		print("  PASS: CRV-007 Dense curve baking into keyframes")
		p += 1

	return p


func test_adjacent_ghost_pipeline() -> int:
	var p := 0
	var pipeline = AdjacentGhostPipelineScript.new(2, 2, 30.0)
	var ghosts: Array = pipeline.generate_ghost_frames(1.0)
	if ghosts.size() == 4:
		print("  PASS: ONI-001 AdjacentGhostPipeline generates preceding/following ghosts")
		p += 1

	return p


func test_key_pinned_ghost_manager() -> int:
	var p := 0
	var manager = KeyPinnedGhostManagerScript.new()
	manager.pin_frame(2.0)
	var pinned: Array = manager.generate_pinned_ghosts(1.0)
	if pinned.size() == 1 and float(pinned[0].get("time")) == 2.0:
		print("  PASS: ONI-002 KeyPinnedGhostManager generates pinned frame ghosts")
		p += 1

	return p


func test_interactive_onion_controller() -> int:
	var p := 0
	var ctrl = InteractiveOnionControllerScript.new()
	var positions := { "1.0:bone_head": Vector2(100, 100) }
	var result: Dictionary = ctrl.hit_test_ghosts(Vector2(102, 101), positions)
	if not result.is_empty() and result.get("part_id") == "bone_head":
		print("  PASS: ONI-003 InteractiveOnionController hit-tests ghost overlay")
		p += 1

	return p


func test_onion_render_style() -> int:
	var p := 0
	var style = OnionRenderStyleScript.new()
	var frame = AdjacentGhostPipelineScript.GhostFrame.new()
	frame.is_past = true
	frame.relative_step = -1

	var color: Color = style.get_ghost_color(frame)
	if color.r > color.b:
		print("  PASS: ONI-004 OnionRenderStyle tints past frames warm/red")
		p += 1

	return p
