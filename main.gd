extends Spatial

"""
A demo of the painter addon.

The brush settings can be configured in a panel to the right. The mesh can be
switched and the result saved as a png.
"""

var changing_size : bool
var change_start_value : float
var stencil_start_transform : Transform2D
var change_start : Vector2
var change_end : Vector2
var painter : Painter

const CHANNELS = {
	albedo = Color.white,
#	ao = Color.white,
#	normal = Color(0.5, 0.5, 1.0),
#	roughness = Color.white,
}

const Brush = preload("addons/painter/brush.gd")
const Painter = preload("addons/painter/painter.gd")
const PropertyPanel = preload("res://addons/property_panel/property_panel.gd")

onready var paintable_model : MeshInstance = $PaintableModel
onready var camera : Camera = $Camera
onready var brush_preview : Spatial = $BrushPreview
onready var brush_property_panel : Panel = $SideBar/VBoxContainer/BrushPropertyPanel
onready var file_dialog : FileDialog = $FileDialog
onready var mesh_option_button : OptionButton = $MeshOptionButton
onready var stencil_preview : TextureRect = $StencilPreview

func _ready() -> void:
	setup_painter()


func _unhandled_input(event: InputEvent) -> void:
	if handle_stencil_input(event) or handle_brush_input(event):
		camera.set_process_input(false)
	else:
		handle_paint_input(event)


func _unhandled_key_input(event : InputEventKey) -> void:
	if event.is_action_pressed("quit"):
		get_tree().quit()
	if event.is_action_pressed("redo"):
		painter.redo()
	elif event.is_action_pressed("undo"):
		painter.undo()


func handle_stencil_input(event : InputEvent) -> bool:
	if not Input.is_action_pressed("change_stencil"):
		return false
	var mouse := get_viewport().get_mouse_position()
	var viewport_size := get_viewport().size
	var middle := viewport_size / 2
	
	if event.is_action_pressed("change_stencil"):
		change_start = mouse
		stencil_start_transform = painter.brush.stencil_transform
		stencil_start_transform.x *= viewport_size.normalized().x
		stencil_start_transform.y *= viewport_size.normalized().y
	
	var start_rotation := -change_start.direction_to(middle).angle()
	var new_rot := -mouse.direction_to(middle).angle()
	painter.brush.stencil_transform = Transform2D(
			stencil_start_transform.get_rotation()\
			+ (new_rot - start_rotation), Vector2())
	var start_scale := change_start.distance_to(middle)
	var scale := stencil_start_transform.get_scale().x\
			- (start_scale - mouse.distance_to(middle)) / 1000.0
	painter.brush.stencil_transform.x /= viewport_size.normalized().x / scale
	painter.brush.stencil_transform.y /= viewport_size.normalized().y / scale
	painter.brush.stencil_transform.origin = Vector2(.5,.5)
	return true


func handle_paint_input(event : InputEvent) -> void:
	if (event is InputEventMouseButton or event is InputEventMouseMotion)\
			and Input.is_action_pressed("paint")\
			and event.position.distance_to(change_end) > 10:
		painter.paint(event.position, 1.0 if event is InputEventMouseButton\
			else event.pressure)
	if event.is_action_released("paint"):
		painter.finish_stroke()
	elif event.is_action_pressed("toggle_eraser"):
		painter.brush.erase = not painter.brush.erase


func handle_brush_input(event : InputEvent) -> bool:
	if event.is_action_pressed("change_size"):
		changing_size = true
		change_start_value = painter.brush.size
		change_start = get_viewport().get_mouse_position()
		brush_preview.follow_mouse = false
		return true
	elif event is InputEventMouseButton and changing_size:
		changing_size = false
		brush_preview.follow_mouse = true
		change_end = event.position
	if event is InputEventMouseMotion and changing_size:
		painter.brush.size = clamp(change_start_value\
			+ (event.position.x - change_start.x) / 100.0, 0.05, 3.0)
	return false


func _on_SaveButton_pressed() -> void:
	file_dialog.popup()


func _on_FileDialog_file_selected(path : String) -> void:
	var data := painter.get_result(0).get_data()
	data.convert(Image.FORMAT_RGBA8)
	data.save_png(path)


func _on_MeshOptionButton_item_selected(index : int) -> void:
	paintable_model.mesh = load("res://assets/models/%s.obj" %\
			mesh_option_button.get_item_text(index).to_lower())
	setup_painter()


func setup_painter() -> void:
	if painter:
		painter.queue_free()
	painter = preload("res://addons/painter/painter.tscn").instance()
	add_child(painter)
	
	var brush := Brush.new()
	brush.tip = preload("res://assets/textures/soft_tip.png")
	brush.colors.append(Color.darkslateblue)
	brush_property_panel.load_brush(brush)
	
	var result = painter.init(paintable_model, Vector2(2048, 2048),
			CHANNELS.size(), brush, CHANNELS.values())
	while result is GDScriptFunctionState:
		result = yield(result, "completed")
	for channel in CHANNELS.size():
		paintable_model.material_override[
				CHANNELS.keys()[channel] + "_texture"] =\
				painter.get_result(channel)
	
	brush_preview.painter = painter.get_path()
	stencil_preview.painter = painter.get_path()
