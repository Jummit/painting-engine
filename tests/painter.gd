extends WATTest

# TODO: Test preview
# TODO: Test complete usage
# TODO: Test stencil

var painter : Node
var mesh_instance : MeshInstance
var brush : Reference
var result_1 : Texture
var result_2 : Texture

const Awaiter = preload("res://addons/painter/utils/awaiter.gd")

const RESULT_SIZE := Vector2(100, 100)
const WINDOW_SIZE := Vector2(512, 512)
const FACE_POS := RESULT_SIZE * Vector2(.5, .8)
const EYE_POS := RESULT_SIZE * Vector2(.9, .35)
const SIDE_POS := RESULT_SIZE * Vector2(.2, .3)

func pre():
	var camera := Camera.new()
	camera.translate(Vector3.BACK * 2)
	OS.window_size = WINDOW_SIZE
	add_child(camera)
	camera.make_current()
	
	mesh_instance = MeshInstance.new()
	mesh_instance.mesh = load("res://assets/models/monkey.obj")
	add_child(mesh_instance)
	
	brush = load("res://addons/painter/brush.gd").new()
	brush.colors = [null, Color.blue]
	brush.textures = [load("tests/red.png")]
	painter = load("res://addons/painter/painter.tscn").instance()
	add_child(painter)
	
	yield(Awaiter.new(painter.init(mesh_instance, RESULT_SIZE, 2, brush, [Color.white, load("tests/red.png")])), "done")
	result_1 = painter.get_result(0)
	result_2 = painter.get_result(1)


func post():
	painter.cleanup()
	painter.queue_free()


func test_initialization():
	describe("Initialize")
	asserts.is_Object(result_1, "Result 1 exists")
	asserts.is_Object(result_2, "Result 2 exists")
	asserts.is_equal(result_1.get_size(), RESULT_SIZE, "Result size one is correct")
	asserts.is_equal(result_2.get_size(), RESULT_SIZE, "Result size two is correct")
	asserts_color_equal(get_pixelv(result_1, RESULT_SIZE / 2), Color.white, "First result is white")
	asserts_color_equal(get_pixelv(result_2, RESULT_SIZE / 2), Color.red, "Second result is red")


func test_painting():
	describe("Paint")
	yield(Awaiter.new(painter.paint(WINDOW_SIZE * 0.5)), "done")
	
	asserts_color_equal(get_pixelv(result_1, FACE_POS), Color.red, "First result's face is painted red")
	asserts_color_equal(get_pixelv(result_1, EYE_POS), Color.red, "First result's eye is painted red")
	asserts_color_equal(get_pixelv(result_1, SIDE_POS), Color.white, "First result's side is still white")
	
	asserts_color_equal(get_pixelv(result_2, FACE_POS), Color.blue, "Second result's face is painted blue")
	asserts_color_equal(get_pixelv(result_2, EYE_POS), Color.blue, "Second result's eye is painted blue")
	asserts_color_equal(get_pixelv(result_2, SIDE_POS), Color.red, "Second result's side is still red")


func test_erasing():
	describe("Erase")
	asserts_color_equal(get_pixelv(result_1, RESULT_SIZE / 2), Color.white, "First result is white")
	asserts_color_equal(get_pixelv(result_2, RESULT_SIZE / 2), Color.red, "Second result is red")
	
	painter.brush.erase = true
	yield(Awaiter.new(painter.paint(WINDOW_SIZE * 0.5)), "done")
	
	asserts.is_equal_or_less_than(get_pixelv(result_1, FACE_POS).a, 0.02, "First result's face is transparent after erasing")
	asserts.is_equal_or_less_than(get_pixelv(result_2, FACE_POS).a, 0.02, "Second result's face is transparent after erasing")
	asserts_color_equal(get_pixelv(result_1, SIDE_POS), Color.white, "First result's side is still white")
	asserts_color_equal(get_pixelv(result_2, SIDE_POS), Color.red, "Second result's side is still red")


func test_undo_erasing():
	describe("Undo an erase")
	painter.brush.erase = true
	yield(Awaiter.new(painter.paint(WINDOW_SIZE * 0.5)), "done")
	yield(Awaiter.new(painter.finish_stroke()), "done")
	
	asserts.is_equal_or_less_than(get_pixelv(result_1, FACE_POS).a, 0.02, "First result's face is transparent after erasing")
	asserts.is_equal_or_less_than(get_pixelv(result_2, FACE_POS).a, 0.02, "Second result's face is transparent after erasing")
	asserts_color_equal(get_pixelv(result_1, SIDE_POS), Color.white, "First result's side is still white")
	asserts_color_equal(get_pixelv(result_2, SIDE_POS), Color.red, "Second result's side is still red")
	
	yield(Awaiter.new(painter.undo()), "done")
	
	asserts_color_equal(get_pixelv(result_1, FACE_POS), Color.white, "First result's face is white again")
	asserts_color_equal(get_pixelv(result_2, FACE_POS), Color.red, "Second result's face is red again")
	asserts_color_equal(get_pixelv(result_1, SIDE_POS), Color.white, "First result's side is still white")
	asserts_color_equal(get_pixelv(result_2, SIDE_POS), Color.red, "Second result's side is still red")
	
	yield(Awaiter.new(painter.redo()), "done")
	
	asserts.is_equal_or_less_than(get_pixelv(result_1, FACE_POS).a, 0.02, "First result's face is transparent again")
	asserts.is_equal_or_less_than(get_pixelv(result_2, FACE_POS).a, 0.02, "Second result's face is transparent again")
	asserts_color_equal(get_pixelv(result_1, SIDE_POS), Color.white, "First result's side is white again")
	asserts_color_equal(get_pixelv(result_2, SIDE_POS), Color.red, "Second result's side is red again")


func test_undo_redo():
	describe("Undo and redo a stroke")
	
	asserts_color_equal(get_pixelv(result_1, RESULT_SIZE / 2), Color.white, "First result is white")
	asserts_color_equal(get_pixelv(result_2, RESULT_SIZE / 2), Color.red, "Second result is red")
	
	yield(Awaiter.new(painter.paint(WINDOW_SIZE * 0.5)), "done")
	yield(Awaiter.new(painter.finish_stroke()), "done")
	
	asserts_color_equal(get_pixelv(result_1, FACE_POS), Color.red, "First result's face is painted red")
	asserts_color_equal(get_pixelv(result_2, FACE_POS), Color.blue, "Second result's face is painted blue")
	
	yield(Awaiter.new(painter.undo()), "done")
	
	asserts_color_equal(get_pixelv(result_1, FACE_POS), Color.white, "First result's face is white again")
	asserts_color_equal(get_pixelv(result_2, FACE_POS), Color.red, "Second result's face is red again")
	
	yield(Awaiter.new(painter.redo()), "done")
	
	asserts_color_equal(get_pixelv(result_1, FACE_POS), Color.red, "First result's face is red again")
	asserts_color_equal(get_pixelv(result_2, FACE_POS), Color.blue, "Second result's face is blue again")


# TODO: Clear with transparent color.
func test_clearing():
	describe("Clear the painter")
	asserts_color_equal(get_pixelv(result_1, RESULT_SIZE / 2), Color.white, "First result is white")
	asserts_color_equal(get_pixelv(result_2, RESULT_SIZE / 2), Color.red, "Second result is red")
	
	yield(Awaiter.new(painter.clear_with([Color.green, load("res://tests/red.png")])), "done")
	
	asserts_color_equal(get_pixelv(result_1, FACE_POS), Color.green, "First result's face is green")
	asserts_color_equal(get_pixelv(result_1, SIDE_POS), Color.green, "First result's side is green")
	asserts_color_equal(get_pixelv(result_2, FACE_POS), Color.red, "First result's face is red")
	asserts_color_equal(get_pixelv(result_2, SIDE_POS), Color.red, "First result's side is red")
	
	yield(Awaiter.new(painter.clear_with([load("res://tests/red.png"), Color.blue])), "done")
	
	asserts_color_equal(get_pixelv(result_1, FACE_POS), Color.red, "First result's face is red")
	asserts_color_equal(get_pixelv(result_1, SIDE_POS), Color.red, "First result's side is red")
	asserts_color_equal(get_pixelv(result_2, FACE_POS), Color.blue, "First result's face is blue")
	asserts_color_equal(get_pixelv(result_2, SIDE_POS), Color.blue, "First result's side is blue")


func get_pixelv(texture : Texture, pos : Vector2) -> Color:
	var image := texture.get_data()
	image.lock()
	return image.get_pixelv(pos)


func asserts_color_equal(a : Color, b : Color, context := "") -> void:
	var typeofa = "Color"
	var typeofb = "Color"
	var passed: String = "|%s| %s is approx. equal to |%s| %s" % [typeofa, a, typeofb, b]
	var failed: String = "|%s| %s is not approx. equal to |%s| %s" % [typeofa, a, typeofb, b]
	var success = Vector3(a.r, a.g, a.b).distance_to(Vector3(b.r, b.g, b.b)) < 0.1
	var expected = passed
	var result = passed if success else failed
	asserts.output(preload("res://addons/WAT/assertions/assertion.gd")._result(success, expected, result, context))
