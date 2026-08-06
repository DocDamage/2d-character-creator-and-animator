# Unit Tests for Mesh & Deformation Studio (Milestone 9 -- MSH-001 through MSH-008, DEF-001 through DEF-006)
# QA-DEF-001: Comprehensive unit test suite for 2D mesh, skinning, weights, handles, and solvers.
extends Node

const MeshDataScript = preload("res://deformation/meshes/mesh_data.gd")
const AutoMeshGeneratorScript = preload("res://deformation/meshes/auto_mesh_generator.gd")
const MeshEditorScript = preload("res://deformation/meshes/mesh_editor.gd")
const UVEditorScript = preload("res://deformation/meshes/uv_editor.gd")
const BoneBinderScript = preload("res://deformation/weights/bone_binder.gd")
const WeightPainterScript = preload("res://deformation/weights/weight_painter.gd")
const WeightNormalizerScript = preload("res://deformation/weights/weight_normalizer.gd")
const PosePreviewScript = preload("res://deformation/weights/pose_preview.gd")
const GridCageDeformationScript = preload("res://deformation/handles/grid_cage_deformation.gd")
const AttractorSolverScript = preload("res://deformation/solvers/attractor_solver.gd")
const SoftDragToolScript = preload("res://deformation/handles/soft_drag_tool.gd")
const AnimatableVertexOffsetScript = preload("res://deformation/solvers/animatable_vertex_offset.gd")
const DeformationBakerScript = preload("res://deformation/solvers/deformation_baker.gd")
const DeformationValidatorScript = preload("res://deformation/solvers/deformation_validator.gd")


func run_tests() -> int:
	print("--- Running Mesh & Deformation Studio Tests (Milestone 9) ---")
	var passes := 0

	passes += test_mesh_data_schema()
	passes += test_auto_mesh_generator()
	passes += test_mesh_editor()
	passes += test_uv_editor()
	passes += test_bone_binder()
	passes += test_weight_painter()
	passes += test_weight_normalizer()
	passes += test_pose_preview()
	passes += test_grid_cage_deformation()
	passes += test_attractor_solver()
	passes += test_soft_drag_tool()
	passes += test_animatable_vertex_offset()
	passes += test_deformation_baker()
	passes += test_deformation_validator()

	print("--- Mesh & Deformation Studio Tests Finished: %d PASS ---" % passes)
	return passes


func test_mesh_data_schema() -> int:
	var p := 0
	var mesh = MeshDataScript.new("test_mesh")
	mesh.add_vertex(Vector2(0, 0), Vector2(0, 0))
	mesh.add_vertex(Vector2(10, 0), Vector2(1, 0))
	mesh.add_vertex(Vector2(0, 10), Vector2(0, 1))
	mesh.add_triangle(0, 1, 2)

	var d: Dictionary = mesh.to_dict()
	var restored = MeshDataScript.new().from_dict(d)

	if restored.mesh_id == "test_mesh" and restored.vertices.size() == 3 and restored.triangles.size() == 1:
		print("  PASS: MSH-001 MeshData round-trip serialization")
		p += 1

	return p


func test_auto_mesh_generator() -> int:
	var p := 0
	var mesh = AutoMeshGeneratorScript.generate_grid_mesh("grid", Rect2(0, 0, 100, 100), 2, 2)
	if mesh.vertices.size() == 9 and mesh.triangles.size() == 8:
		print("  PASS: MSH-002 Grid mesh auto-generator")
		p += 1

	var pts: Array[Vector2] = [Vector2(0, 0), Vector2(100, 0), Vector2(50, 100)]
	var tris: Array = AutoMeshGeneratorScript.delaunay_triangulate_points(pts)
	if tris.size() == 1:
		print("  PASS: MSH-002 Delaunay triangulation algorithm")
		p += 1

	return p


func test_mesh_editor() -> int:
	var p := 0
	var mesh = AutoMeshGeneratorScript.generate_grid_mesh("grid", Rect2(0, 0, 100, 100), 1, 1)
	var editor = MeshEditorScript.new(mesh)

	var mid_id: int = editor.insert_vertex(Vector2(50, 50), Vector2(0.5, 0.5))
	if mid_id >= 0 and mesh.vertices.size() == 5:
		print("  PASS: MSH-003 Manual vertex insertion and triangle splitting")
		p += 1

	return p


func test_uv_editor() -> int:
	var p := 0
	var mesh = AutoMeshGeneratorScript.generate_grid_mesh("grid", Rect2(0, 0, 200, 200), 1, 1)
	UVEditorScript.normalize_uvs(mesh, Rect2(0, 0, 200, 200))
	var v_top_right = mesh.vertices[1]
	if (v_top_right.uv as Vector2).distance_to(Vector2(1, 0)) < 0.001:
		print("  PASS: MSH-004 UV coordinate normalization")
		p += 1

	return p


func test_bone_binder() -> int:
	var p := 0
	var mesh = AutoMeshGeneratorScript.generate_grid_mesh("grid", Rect2(0, 0, 100, 100), 1, 1)
	var bones := [
		{ "bone_id": "root", "head_pos": Vector2(0, 50), "tail_pos": Vector2(100, 50) }
	]

	BoneBinderScript.auto_bind_weights(mesh, bones)
	var v0 = mesh.vertices[0]
	if not v0.bone_weights.is_empty() and str(v0.bone_weights[0].bone_id) == "root":
		print("  PASS: MSH-005 Automated bone weight binding")
		p += 1

	return p


func test_weight_painter() -> int:
	var p := 0
	var mesh = AutoMeshGeneratorScript.generate_grid_mesh("grid", Rect2(0, 0, 100, 100), 1, 1)
	var painter = WeightPainterScript.new()
	painter.active_bone_id = "arm_L"
	painter.paint_stroke(mesh, Vector2(0, 0))

	var v0 = mesh.vertices[0]
	if not v0.bone_weights.is_empty() and str(v0.bone_weights[0].bone_id) == "arm_L":
		print("  PASS: MSH-006 Interactive brush weight painting")
		p += 1

	return p


func test_weight_normalizer() -> int:
	var p := 0
	var v = MeshDataScript.VertexData.new(0, Vector2(0, 0), Vector2(0, 0))
	v.bone_weights.append(MeshDataScript.BoneWeightData.new("b1", 2.0))
	v.bone_weights.append(MeshDataScript.BoneWeightData.new("b2", 2.0))

	WeightNormalizerScript.normalize_vertex_weights(v)
	if absf(float(v.bone_weights[0].weight) - 0.5) < 0.001:
		print("  PASS: MSH-007 Weight normalization sum to 1.0")
		p += 1

	return p


func test_pose_preview() -> int:
	var p := 0
	var mesh = AutoMeshGeneratorScript.generate_grid_mesh("grid", Rect2(0, 0, 100, 100), 1, 1)
	var bones := [{ "bone_id": "b1", "head_pos": Vector2(0, 0), "tail_pos": Vector2(100, 0) }]
	BoneBinderScript.auto_bind_weights(mesh, bones)

	var stretch: float = PosePreviewScript.test_extreme_bone_rotation(mesh, "b1", Vector2(0, 0), 45.0)
	if stretch >= 1.0:
		print("  PASS: MSH-008 Extreme pose preview stretch calculation")
		p += 1

	return p


func test_grid_cage_deformation() -> int:
	var p := 0
	var cage = GridCageDeformationScript.new()
	cage.add_pin("pin1", Vector2(50, 50), 64.0)
	cage.move_pin("pin1", Vector2(70, 50))

	var offset: Vector2 = cage.evaluate_vertex_displacement(Vector2(50, 50))
	if offset.distance_to(Vector2(20, 0)) < 0.001:
		print("  PASS: DEF-001 Grid cage pin deformation offset")
		p += 1

	return p


func test_attractor_solver() -> int:
	var p := 0
	var solver = AttractorSolverScript.new()
	solver.add_point_attractor("att1", Vector2(100, 0), 200.0, 1.0)
	var disp: Vector2 = solver.solve_displacement(Vector2(0, 0))
	if disp.x > 0.0:
		print("  PASS: DEF-002 Point attractor force field solver")
		p += 1

	return p


func test_soft_drag_tool() -> int:
	var p := 0
	var tool = SoftDragToolScript.new()
	tool.start_drag(Vector2(0, 0))

	var mesh = AutoMeshGeneratorScript.generate_grid_mesh("grid", Rect2(0, 0, 100, 100), 1, 1)
	var res: Array[Vector2] = tool.evaluate_drag_offsets(mesh.vertices, Vector2(10, 0))
	if res[0].x > 0.0:
		print("  PASS: DEF-003 Soft drag falloff tool displacement")
		p += 1

	return p


func test_animatable_vertex_offset() -> int:
	var p := 0
	var anim = AnimatableVertexOffsetScript.new("track1", 0)
	anim.add_offset_key(0.0, Vector2(0, 0))
	anim.add_offset_key(2.0, Vector2(20, 40))

	var off: Vector2 = anim.evaluate_offset(1.0)
	if off.distance_to(Vector2(10, 20)) < 0.001:
		print("  PASS: DEF-004 Animatable vertex offset interpolation")
		p += 1

	return p


func test_deformation_baker() -> int:
	var p := 0
	var mesh = AutoMeshGeneratorScript.generate_grid_mesh("grid", Rect2(0, 0, 100, 100), 1, 1)
	var def_pos: Array[Vector2] = [Vector2(10, 10), Vector2(110, 10), Vector2(10, 110), Vector2(110, 110)]
	var baked = DeformationBakerScript.bake_deformed_mesh(mesh, def_pos)
	if baked != null and (baked.vertices[0].position as Vector2) == Vector2(10, 10):
		print("  PASS: DEF-005 Deformation baking into static mesh")
		p += 1

	return p


func test_deformation_validator() -> int:
	var p := 0
	var mesh = AutoMeshGeneratorScript.generate_grid_mesh("grid", Rect2(0, 0, 100, 100), 1, 1)
	var bones := [{ "bone_id": "b1", "head_pos": Vector2(0, 0), "tail_pos": Vector2(100, 0) }]
	BoneBinderScript.auto_bind_weights(mesh, bones)

	var errs: Array[String] = DeformationValidatorScript.validate_mesh(mesh)
	if errs.is_empty():
		print("  PASS: DEF-006 Deformation validator verifies clean mesh")
		p += 1

	return p
