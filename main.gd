extends Node3D

## A demo of the painter addon.
##
## The brush settings can be configured in a panel to the right. The mesh can be
## switched and the result saved as a png.

var changing_size : bool
var change_start_value : float
var last_stencil : Transform2D
var change_start : Vector2
var painter : Painter
var brush := Brush.new()
## Where the user clicked to end resizing the brush.
var released_at : Vector2
## Tracking if a motion event should continue a stroke.
var brush_down := false

const BrushPropertyPanel = preload("res://brush_property_panel.gd")
const StencilPreview = preload("res://addons/painter/preview/stencil_preview.gd")

const CHANNELS = {
	albedo = Color(0.8, 0.8, 0.8),
	ao = Color.WHITE,
	roughness = Color(0.8, 0.8, 0.8),
	normal = Color(0.5, 0.5, 1.0),
}

@onready var brush_property_panel : BrushPropertyPanel = %BrushPropertyPanel
@onready var brush_preview : BrushPreview = %BrushPreview
@onready var paintable_model : MeshInstance3D = %PaintableModel
@onready var camera : NavigationCamera = %NavigationCamera
@onready var stencil_preview : StencilPreview = %StencilPreview
@onready var save_file_dialog : FileDialog = %SaveFileDialog
@onready var mesh_option_button : OptionButton = %MeshOptionButton
@onready var error_dialog: AcceptDialog = $ErrorDialog

func _ready() -> void:
	setup_painter()
	get_tree().auto_accept_quit = false
	brush.tip = preload("res://assets/textures/soft_tip.png")
	brush.colors = [Color.DARK_SLATE_BLUE, Color.DARK_SLATE_BLUE, Color.DARK_SLATE_BLUE, Color(0.5, 0.5, 1.0)]
	brush_property_panel.load_brush(brush)
	stencil_preview.brush = brush
	brush_preview.brush = brush
	delete_undo_textures()


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
	save_file_dialog.popup_centered_ratio(0.4)


func _on_MeshOptionButton_item_selected(index : int) -> void:
	paintable_model.mesh = load("res://assets/models/%s.obj" %\
			mesh_option_button.get_item_text(index).to_lower())
	setup_painter()


func _on_save_file_dialog_dir_selected(dir: String) -> void:
	var maps := CHANNELS.keys()
	for map_num in maps.size():
		var data = painter.get_result(map_num).get_image()
		data.convert(Image.FORMAT_RGBA8)
		var path := dir.path_join(maps[map_num]) + ".png"
		var err := data.save_png(path)
		if err != OK:
			error_dialog.dialog_text = "Couldn't save png to %s: %s" % [path,
					error_string(err)]
			error_dialog.popup_centered()


func handle_stencil_input(event : InputEvent) -> bool:
	var mouse := get_viewport().get_mouse_position()
	var viewport_size = (get_viewport() as Window).size
	var viewport_ratio = Vector2(viewport_size).normalized()
	if event.is_action("change_stencil") or event.is_action("grab_stencil"):
		change_start = mouse
		last_stencil = brush.stencil_transform
		last_stencil.x *= viewport_ratio.x
		last_stencil.y *= viewport_ratio.y
	if Input.is_action_pressed("grab_stencil"):
		brush.stencil_transform.origin = last_stencil.origin\
			+ (mouse - change_start) / Vector2(viewport_size)
		return true
	elif Input.is_action_pressed("change_stencil"):
		var stencil_pos = last_stencil.origin * viewport_size
		var start_rotation := -change_start.direction_to(stencil_pos).angle()
		var new_rot := -mouse.direction_to(stencil_pos).angle()
		brush.stencil_transform = Transform2D(
				last_stencil.get_rotation() + (new_rot - start_rotation),
				brush.stencil_transform.origin)
		var start_scale := change_start.distance_to(stencil_pos)
		var stencil_scale := last_stencil.get_scale().x\
				- (start_scale - mouse.distance_to(stencil_pos)) / 1000.0
		brush.stencil_transform.x /= viewport_ratio.x / stencil_scale
		brush.stencil_transform.y /= viewport_ratio.y / stencil_scale
		return true
	return false


func handle_paint_input(event : InputEvent) -> void:
	if event.is_action_released("paint"):
		painter.finish_stroke()
	elif event.is_action_pressed("toggle_eraser"):
		brush.erase = not brush.erase
	if Input.is_action_pressed("paint"):
		var mouse_event := event as InputEventMouse
		if mouse_event and released_at.distance_to(mouse_event.position) < 50:
			# Don't paint after clicking to finish resizing brush.
			return
		released_at = Vector2.ZERO
		var button_event := event as InputEventMouseButton
		var motion_event := event as InputEventMouseMotion
		if button_event:
			painter.paint(button_event.position, brush, 1.0)
			brush_down = true
		elif motion_event:
			if brush_down:
				# Continue stroke.
				painter.paint_to(motion_event.position, brush, motion_event.pressure)
			else:
				painter.paint(motion_event.position, brush, 1.0)
	else:
		brush_down = false


func handle_brush_input(event : InputEvent) -> bool:
	var button_event := event as InputEventMouseButton
	var motion_event := event as InputEventMouseMotion
	if event.is_action_pressed("change_size"):
		changing_size = true
		change_start_value = brush.size
		change_start = get_viewport().get_mouse_position()
		brush_preview.follow_mouse = false
		return true
	elif button_event and changing_size:
		released_at = get_viewport().get_mouse_position()
		changing_size = false
		brush_preview.follow_mouse = true
	if motion_event and changing_size:
		brush.size = clamp(change_start_value\
			+ (motion_event.position.x - change_start.x) / 100.0, 0.05, 3.0)
	return false


func setup_painter() -> void:
	if painter:
		painter.queue_free()
	painter = preload("res://addons/painter/painter.tscn").instantiate()
	add_child(painter)
	await painter.init(paintable_model, Vector2(2048, 2048), CHANNELS.size())
	await painter.clear_with(CHANNELS.values())
	for channel in CHANNELS.size():
		paintable_model.material_override[
				CHANNELS.keys()[channel] + "_texture"] =\
				painter.get_result(channel)
	brush_preview.painter = painter.get_path()
	brush_preview.show()


func delete_undo_textures():
	var undo_textures := DirAccess.open("user://undo_textures")
	if undo_textures:
		for folder in undo_textures.get_directories():
			var sub := DirAccess.open(undo_textures.get_current_dir().path_join(folder))
			for sub_folder in sub.get_directories():
				var sub_sub := DirAccess.open(sub.get_current_dir().path_join(sub_folder))
				for file in sub_sub.get_files():
					var _err := sub_sub.remove(file)
				var _err := sub.remove(sub_folder)
			var _err := undo_textures.remove(folder)
