extends WATTest

# TODO: Test complete usage
# TODO: Test stencil

var painter : Node
var mesh_instance : MeshInstance3D
var brush : RefCounted
var result_1 : Texture2D
var result_2 : Texture2D

const Awaiter = preload("res://addons/painter/utils/awaiter.gd")

const RESULT_SIZE := Vector2(100, 100)
const WINDOW_SIZE := Vector2(512, 512)
const FACE_POS := RESULT_SIZE * Vector2(.5, .8)
const EYE_POS := RESULT_SIZE * Vector2(.9, .35)
const SIDE_POS := RESULT_SIZE * Vector2(.2, .3)

func pre():
	var camera := Camera3D.new()
	camera.translate(Vector3.BACK * 2)
	OS.window_size = WINDOW_SIZE
	add_child(camera)
	camera.make_current()
	
	mesh_instance = MeshInstance3D.new()
	mesh_instance.mesh = load("res://assets/models/monkey.obj")
	add_child(mesh_instance)
	
	brush = load("res://addons/painter/brush.gd").new()
	brush.colors = [null, Color.BLUE]
	brush.textures = [load("tests/red.png")]
	painter = load("res://addons/painter/painter.tscn").instantiate()
	add_child(painter)
	
	await Awaiter.new(painter.init(mesh_instance, RESULT_SIZE, 2, brush, [Color.WHITE, load("tests/red.png")])).done
	result_1 = painter.get_data(0)
	result_2 = painter.get_data(1)


func post():
	painter.cleanup()
	painter.queue_free()


func test_initialization():
	describe("Initialize")
	asserts.is_Object(result_1, "Result 1 exists")
	asserts.is_Object(result_2, "Result 2 exists")
	asserts.is_equal(result_1.get_size(), RESULT_SIZE, "Result size one is correct")
	asserts.is_equal(result_2.get_size(), RESULT_SIZE, "Result size two is correct")
	asserts_color_equal(get_pixelv(result_1, RESULT_SIZE / 2), Color.WHITE, "First result is white")
	asserts_color_equal(get_pixelv(result_2, RESULT_SIZE / 2), Color.RED, "Second result is red")


func test_painting():
	describe("Paint")
	await Awaiter.new(painter.paint(WINDOW_SIZE * 0.5)).done
	asserts_color_equal(get_pixelv(result_1, FACE_POS), Color.RED, "First result's face is painted red")
	asserts_color_equal(get_pixelv(result_1, EYE_POS), Color.RED, "First result's eye is painted red")
	asserts_color_equal(get_pixelv(result_1, SIDE_POS), Color.WHITE, "First result's side is still white")
	asserts_color_equal(get_pixelv(result_2, FACE_POS), Color.BLUE, "Second result's face is painted blue")
	asserts_color_equal(get_pixelv(result_2, EYE_POS), Color.BLUE, "Second result's eye is painted blue")
	asserts_color_equal(get_pixelv(result_2, SIDE_POS), Color.RED, "Second result's side is still red")


func test_erasing():
	describe("Erase")
	painter.brush.erase = true
	await Awaiter.new(painter.paint(WINDOW_SIZE * 0.5)).done
	asserts.is_equal_or_less_than(get_pixelv(result_1, FACE_POS).a, 0.02, "First result's face is transparent")
	asserts.is_equal_or_less_than(get_pixelv(result_2, FACE_POS).a, 0.02, "Second result's face is transparent")
	asserts_color_equal(get_pixelv(result_1, SIDE_POS), Color.WHITE, "First result's side is still white")
	asserts_color_equal(get_pixelv(result_2, SIDE_POS), Color.RED, "Second result's side is still red")


func test_undo_erasing():
	describe("Undo an erase")
	painter.brush.erase = true
	await Awaiter.new(painter.paint(WINDOW_SIZE * 0.5)).done
	await Awaiter.new(painter.finish_stroke()).done
	await Awaiter.new(painter.undo()).done
	asserts_color_equal(get_pixelv(result_1, FACE_POS), Color.WHITE, "First result's face is white again")
	asserts_color_equal(get_pixelv(result_2, FACE_POS), Color.RED, "Second result's face is red again")
	asserts_color_equal(get_pixelv(result_1, SIDE_POS), Color.WHITE, "First result's side is still white")
	asserts_color_equal(get_pixelv(result_2, SIDE_POS), Color.RED, "Second result's side is still red")


func test_redo_erasing():
	describe("Redo an erase")
	painter.brush.erase = true
	await Awaiter.new(painter.paint(WINDOW_SIZE * 0.5)).done
	await Awaiter.new(painter.finish_stroke()).done
	await Awaiter.new(painter.undo()).done
	await Awaiter.new(painter.redo()).done
	asserts.is_equal_or_less_than(get_pixelv(result_1, FACE_POS).a, 0.02, "First result's face is transparent again")
	asserts.is_equal_or_less_than(get_pixelv(result_2, FACE_POS).a, 0.02, "Second result's face is transparent again")
	asserts_color_equal(get_pixelv(result_1, SIDE_POS), Color.WHITE, "First result's side is white again")
	asserts_color_equal(get_pixelv(result_2, SIDE_POS), Color.RED, "Second result's side is red again")


func test_undo():
	describe("Undo a stroke")
	await Awaiter.new(painter.paint(WINDOW_SIZE * 0.5)).done
	await Awaiter.new(painter.finish_stroke()).done
	await Awaiter.new(painter.undo()).done
	asserts_color_equal(get_pixelv(result_1, FACE_POS), Color.WHITE, "First result's face is white again")
	asserts_color_equal(get_pixelv(result_2, FACE_POS), Color.RED, "Second result's face is red again")


func test_redo():
	describe("Redo a stroke")
	await Awaiter.new(painter.paint(WINDOW_SIZE * 0.5)).done
	await Awaiter.new(painter.finish_stroke()).done
	await Awaiter.new(painter.undo()).done
	await Awaiter.new(painter.redo()).done
	asserts_color_equal(get_pixelv(result_1, FACE_POS), Color.RED, "First result's face is red again")
	asserts_color_equal(get_pixelv(result_2, FACE_POS), Color.BLUE, "Second result's face is blue again")


func test_clear_with_color():
	describe("Clear the painter with a single color")
	await Awaiter.new(painter.clear_with([Color.GREEN])).done
	asserts_color_equal(get_pixelv(result_1, FACE_POS), Color.GREEN, "First result's face is green")


func test_clearing_multiple_channels():
	describe("Clear multiple channels of the painter")
	await Awaiter.new(painter.clear_with([Color.GREEN, load("res://tests/red.png")])).done
	asserts_color_equal(get_pixelv(result_1, FACE_POS), Color.GREEN, "First result's face is green")
	asserts_color_equal(get_pixelv(result_2, FACE_POS), Color.RED, "Second result's face is red")


func test_clear_with_image():
	describe("Clear the painter with an image")
	await Awaiter.new(painter.clear_with([load("res://tests/red.png")])).done
	asserts_color_equal(get_pixelv(result_1, FACE_POS), Color.RED, "First result's face is red")


func test_clear_with_transparent_color():
	describe("Clear the painter with a color that has an alpha value below zero")
	await Awaiter.new(painter.clear_with([Color(1, 0, 0, 0.5)])).done
	asserts_color_equal(get_pixelv(result_1, FACE_POS), Color(1, 0, 0, 0.5), "First result's face is transparent")


func get_pixelv(texture : Texture2D, pos : Vector2) -> Color:
	var image := texture.get_data()
	false # image.lock() # TODOConverter40, image no longer require locking, `false` helps to not broke one line if/else, so can be freely removed
	return image.get_pixelv(pos)


func asserts_color_equal(a : Color, b : Color, context := "") -> void:
	var typeofa = "Color"
	var typeofb = "Color"
	var passed: String = "|%s| %s is approx. equal to |%s| %s" % [typeofa, a, typeofb, b]
	var failed: String = "|%s| %s is not approx. equal to |%s| %s" % [typeofa, a, typeofb, b]
	var success := true
	for pair in [[a.r, b.r], [a.r, b.r], [a.r, b.r], [a.r, b.r]]:
		if abs(pair[1] - pair[0]) > 0.016:
			success = false
			break
	var expected = passed
	var result = passed if success else failed
	asserts.output(preload("res://addons/WAT/assertions/assertion.gd")._result(success, expected, result, context))
