extends WATTest

var painter : Node
var mesh_instance : MeshInstance
var brush : Reference

const WINDOW_SIZE := Vector2(512, 512)
const Assertion = preload("res://addons/WAT/assertions/assertion.gd")

func start():
	OS.window_size = WINDOW_SIZE

	var camera := Camera.new()
	camera.translate(Vector3.BACK * 2)
	add_child(camera)
	camera.make_current()
	
	mesh_instance = MeshInstance.new()
	mesh_instance.mesh = load("res://assets/models/monkey.obj")
	add_child(mesh_instance)

	painter = load("res://addons/painter/painter.tscn").instance()
	add_child(painter)
	brush = load("res://addons/painter/brush.gd").new()
	painter.init(mesh_instance, Vector2(10,10), 2, brush, [])


func pre():
	brush = load("res://addons/painter/brush.gd").new()
	painter.brush = brush


func test_position_in_empty_space():
	var transforms : Array = painter.get_brush_preview_transforms(
			Vector2(3,3), 1, true)
	transform_equal_approx(transforms.front(),
			Transform().translated(Vector3(-2.47, 1.39, 0)))


func test_single_mirror_symmetry():
	describe("When using single mirror symmetry multiple previews are shown")
	painter.brush.symmetry = painter.Brush.Symmetry.MIRROR
	painter.brush.symmetry_axis = Vector3.RIGHT
	asserts.is_equal(painter.get_brush_preview_transforms(
			get_viewport().size / 2, 1, true).size(), 2)


func test_multi_mirror_symmetry():
	describe("When using mirror symmetry on multiple axis multiple previews are shown")
	painter.brush.symmetry = painter.Brush.Symmetry.MIRROR
	painter.brush.symmetry_axis = Vector3(1, 1, 0)
	asserts.is_equal(painter.get_brush_preview_transforms(
			get_viewport().size / 2, 1, true).size(), 4)


func test_radial_symmetry():
	describe("When using radial symmetry multiple previews are shown")
	painter.brush.symmetry = painter.Brush.Symmetry.RADIAL
	painter.brush.radial_symmetry_count = 6
	painter.brush.symmetry_axis = Vector3.UP
	asserts.is_equal(painter.get_brush_preview_transforms(
			get_viewport().size / 2, 1, true).size(), 6)


func test_one_preview_with_symmetry():
	describe("When using symmetry and in empty space one preview is shown")
	painter.brush.symmetry = painter.Brush.Symmetry.MIRROR
	painter.brush.symmetry_axis = Vector3.RIGHT
	asserts.is_equal(painter.get_brush_preview_transforms(
			Vector2(0, 0), 1, true).size(), 1)


func transform_equal_approx(a, b, context := ""):
	var passed: String = "%s is approx. equal to %s" % [a, b]
	var failed: String = "%s is not approx. equal to %s" % [a, b]
	var success = true
	for v in [a.basis.x.distance_to(b.basis.x),
			a.basis.y.distance_to(b.basis.y), a.basis.z.distance_to(b.basis.z),
			a.origin.distance_to(b.origin)]:
		if v > 0.2:
			success = false
			break
	var expected = passed
	var result = passed if success else failed
	asserts.output(Assertion._result(success, expected, result, context))

