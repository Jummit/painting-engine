extends Node3D

## A demo of the painter addon.
##
## The brush settings can be configured in a panel to the right. The mesh can be
## switched and the result saved as a png.

var changing_size : bool
var change_start_value : float
var last_stencil : Transform2D
var change_start : Vector2
var change_end : Vector2
var painter : Painter

const BrushPropertyPanel = preload("res://brush_property_panel.gd")
const StencilPreview = preload("res://addons/painter/preview/stencil_preview.gd")

const CHANNELS = {
	albedo = Color.WHITE,
	ao = Color.WHITE,
	normal = Color(0.5, 0.5, 1.0),
	roughness = Color.WHITE,
}

@onready var brush_property_panel : BrushPropertyPanel = %BrushPropertyPanel
@onready var brush_preview : BrushPreview = %BrushPreview
@onready var paintable_model : MeshInstance3D = %PaintableModel
@onready var camera : NavigationCamera = %NavigationCamera
@onready var stencil_preview : StencilPreview = %StencilPreview
@onready var file_dialog : FileDialog = %FileDialog
@onready var mesh_option_button : OptionButton = %MeshOptionButton
@onready var error_dialog: AcceptDialog = $ErrorDialog

func _ready() -> void:
	setup_painter()
	get_tree().auto_accept_quit = false


func _notification(what):
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		painter.cleanup()
		get_tree().quit()


func _unhandled_input(event: InputEvent) -> void:
	if handle_stencil_input(event) or handle_brush_input(event):
		camera.set_process_input(false)
	else:
		handle_paint_input(event)


func _unhandled_key_input(event : InputEvent) -> void:
	if event.is_action_pressed("quit"):
		get_tree().quit()
	if event.is_action_pressed("redo"):
		var _success := await painter.redo()
	elif event.is_action_pressed("undo"):
		var _success := await painter.undo()


func _on_SaveButton_pressed() -> void:
	file_dialog.popup_centered_ratio()


func _on_FileDialog_file_selected(path : String) -> void:
	var data = painter.get_result(0).get_image()
	data.convert(Image.FORMAT_RGBA8)
	var err := data.save_png(path)
	if err != OK:
		error_dialog.dialog_text = "Couldn't save png to %s: %s" % [path,
				error_string(err)]
		error_dialog.popup_centered()


func _on_MeshOptionButton_item_selected(index : int) -> void:
	paintable_model.mesh = load("res://assets/models/%s.obj" %\
			mesh_option_button.get_item_text(index).to_lower())
	setup_painter()


func handle_stencil_input(event : InputEvent) -> bool:
	var mouse := get_viewport().get_mouse_position()
	var viewport_size = (get_viewport() as Window).size
	var viewport_ratio = Vector2(viewport_size).normalized()
	if event.is_action("change_stencil") or event.is_action("grab_stencil"):
		change_start = mouse
		last_stencil = painter.brush.stencil_transform
		last_stencil.x *= viewport_ratio.x
		last_stencil.y *= viewport_ratio.y
	if Input.is_action_pressed("grab_stencil"):
		painter.brush.stencil_transform.origin = last_stencil.origin\
			+ (mouse - change_start) / Vector2(viewport_size)
		return true
	elif Input.is_action_pressed("change_stencil"):
		var stencil_pos = last_stencil.origin * viewport_size
		var start_rotation := -change_start.direction_to(stencil_pos).angle()
		var new_rot := -mouse.direction_to(stencil_pos).angle()
		painter.brush.stencil_transform = Transform2D(
				last_stencil.get_rotation() + (new_rot - start_rotation),
				painter.brush.stencil_transform.origin)
		var start_scale := change_start.distance_to(stencil_pos)
		var stencil_scale := last_stencil.get_scale().x\
				- (start_scale - mouse.distance_to(stencil_pos)) / 1000.0
		painter.brush.stencil_transform.x /= viewport_ratio.x / stencil_scale
		painter.brush.stencil_transform.y /= viewport_ratio.y / stencil_scale
		return true
	return false


func handle_paint_input(event : InputEvent) -> void:
	if Input.is_action_pressed("paint"):
		var button_event := event as InputEventMouseButton
		var motion_event := event as InputEventMouseMotion
		if button_event:
			painter.paint(button_event.position, 1.0)
		elif motion_event:
			painter.paint_to(motion_event.position, motion_event.pressure)
	if event.is_action_released("paint"):
		painter.finish_stroke()
	elif event.is_action_pressed("toggle_eraser"):
		painter.brush.erase = not painter.brush.erase


func handle_brush_input(event : InputEvent) -> bool:
	var button_event := event as InputEventMouseButton
	var motion_event := event as InputEventMouseMotion
	if event.is_action_pressed("change_size"):
		changing_size = true
		change_start_value = painter.brush.size
		change_start = get_viewport().get_mouse_position()
		brush_preview.follow_mouse = false
		return true
	elif button_event and changing_size:
		changing_size = false
		brush_preview.follow_mouse = true
		change_end = button_event.position
	if motion_event and changing_size:
		painter.brush.size = clamp(change_start_value\
			+ (motion_event.position.x - change_start.x) / 100.0, 0.05, 3.0)
	return false


func setup_painter() -> void:
	if painter:
		painter.queue_free()
	painter = preload("res://addons/painter/painter.tscn").instantiate()
	add_child(painter)
	
	var brush := Brush.new()
	brush.tip = preload("res://assets/textures/soft_tip.png")
	brush.colors.append(Color.DARK_SLATE_BLUE)
	brush_property_panel.load_brush(brush)
	
	await painter.init(paintable_model, Vector2(2048, 2048), CHANNELS.size())
	painter.brush = brush
	painter.clear_with(CHANNELS.values())
	for channel in CHANNELS.size():
		paintable_model.material_override[
				CHANNELS.keys()[channel] + "_texture"] =\
				painter.get_result(channel)
	
	brush_preview.painter = painter.get_path()
	stencil_preview.painter = painter.get_path()
