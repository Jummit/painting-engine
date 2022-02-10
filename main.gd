extends Spatial

"""
A demo of the painter addon.

The brush settings can be configured in a panel to the right. The mesh can be
switched and the result saved as a png.
"""

var changing_stencil : bool
var changing_size : bool
var prev_scale : float
var prev_rot : float
var change_start_value : float
var change_start : Vector2
var change_end : Vector2
var painter : Painter
var editable_brush : EditableBrush

const CHANNELS = {
	albedo = Color.white,
#	ao = Color.white,
#	normal = Color(0.5, 0.5, 1.0),
#	roughness = Color.white,
}

const SYMMETRY_AXIS := {
	none = Vector3.ZERO,
	x = Vector3.RIGHT,
	y = Vector3.UP,
	z = Vector3.FORWARD,
}

const Brush = preload("addons/painter/brush.gd")
const Painter = preload("addons/painter/painter.gd")
const PropertyPanel = preload("res://addons/property_panel/property_panel.gd")
const Properties = preload("res://addons/property_panel/properties.gd")
const FileUtils = preload("res://addons/file_utils/file_utils.gd")

onready var paintable_model : MeshInstance = $PaintableModel
onready var camera : Camera = $Camera
onready var brush_preview : Spatial = $BrushPreview
onready var brush_property_panel : Panel = $SideBar/VBoxContainer/BrushPropertyPanel
onready var file_dialog : FileDialog = $FileDialog
onready var mesh_option_button : OptionButton = $MeshOptionButton
onready var stencil_preview : TextureRect = $StencilPreview

class EditableBrush:
	var brush

	func _init(_brush) -> void:
		brush = _brush

	func _set(property: String, value) -> bool:
		match property:
			"color":
				brush.colors = [value]
			"texture":
				var texture := FileUtils.as_texture(value)
				if texture:
					brush.textures = [texture]
				else:
					brush.textures = []
			"symmetry":
				brush.symmetry = Brush.Symmetry[value]
			"symmetry_axis":
				brush.symmetry_axis = SYMMETRY_AXIS[value]
			"projection":
				brush.projection = Brush.Projection[value]
			"tip":
				brush.tip = FileUtils.as_texture(value)
			_:
				if property in brush:
					brush[property] = value
				else:
					return false
		return true

	func _get(property: String):
		match property:
			"color":
				return brush.get_color(0)
			"texture":
				return brush.get_texture(0)
			"symmetry":
				return Brush.Symmetry.keys()[brush.symmetry]
			"symmetry_axis":
				return SYMMETRY_AXIS.values()[SYMMETRY_AXIS.values().find(brush.symmetry_axis)]
			"projection":
				return Brush.Projection.keys()[brush.projection]
			"tip":
				return "" if not brush.tip else brush.tip.resource_path
			_:
				return brush.get(property)

func _ready() -> void:
	brush_property_panel.set_properties([
		"Texture",
		Properties.FilePathProperty.new("tip"),
		Properties.FilePathProperty.new("texture"),
		Properties.ColorProperty.new("color"),
		Properties.BoolProperty.new("follow_path"),
		Properties.FloatProperty.new("spacing", 0, 1),
		Properties.FloatProperty.new("angle", 0, 1),
		"Flow/Opacity",
		Properties.FloatProperty.new("stroke_opacity", 0, 1),
		Properties.FloatProperty.new("flow", 0, 1),
		Properties.BoolProperty.new("flow_pen_pressure"),
		Properties.BoolProperty.new("size_pen_pressure"),
		"Randomness",
		Properties.FloatProperty.new("angle_jitter", 0, 1),
		Properties.FloatProperty.new("size_jitter", 0, 1),
		Properties.FloatProperty.new("position_jitter", 0, 1),
		"Symmetry",
		Properties.EnumProperty.new("symmetry", Brush.Symmetry.keys()),
		Properties.EnumProperty.new("symmetry_axis", SYMMETRY_AXIS.keys()),
		Properties.IntProperty.new("radial_symmetry_count", 2, 12),
		"Misc",
		Properties.EnumProperty.new("projection", Brush.Projection.keys()),
		Properties.FilePathProperty.new("stencil"),
	])
	
	setup_painter()


func _unhandled_input(event: InputEvent) -> void:
	if handle_mask_input(event) or handle_brush_input(event):
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


func handle_mask_input(event : InputEvent) -> bool:
	if event is InputEventMouseMotion and Input.is_action_pressed("change_stencil"):
		if Input.is_action_pressed("scale_stencil"):
			painter.brush.mask_transform = painter.brush.mask_transform.scaled(
				Vector2.ONE + Vector2.ONE * event.relative.x / 500)
			return true
		elif Input.is_action_pressed("rotate_stencil"):
			painter.brush.mask_transform =\
				painter.brush.mask_transform.rotated(event.relative.x / 300)
			return true
		elif Input.is_action_pressed("move_stencil"):
			painter.brush.mask_transform =\
				painter.brush.mask_transform.translated(event.relative / 1000)
			return true
	elif event is InputEventMouseButton and not event.pressed:
		camera.set_process_input(true)
	elif event.is_action_pressed("toggle_stencil"):
		painter.brush.mask = preload("assets/textures/bow.jpg") if\
			not painter.brush.mask else null
	return false


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


func _on_BrushPropertyPanel_property_changed(_property : String, _value) -> void:
	brush_property_panel.store_values(editable_brush)


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
	editable_brush = EditableBrush.new(brush)
	brush_property_panel.load_values(editable_brush)
	
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
