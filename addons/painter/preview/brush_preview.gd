extends Node3D

## Interactive in-viewport brush peview.

## Uses the tip and first texture and color to show a preview of what the brush
## looks like.

enum Appearance {
	BRUSH, ## A preview of what the brush will paint.
	CIRCLE, ## A neutral black-and-white striped circle.
}

@export var appearance: Appearance = Appearance.BRUSH:
	set(to):
		appearance = to
		for preview in _previews:
			preview.set_surface_override_material(0, preload("brush_preview.material") if\
					appearance == Appearance.BRUSH else\
					preload("circle_preview.material"))
@export var painter := NodePath("../Painter") :
	set(to):
		painter = to
		if to:
			_painter = get_node(painter)

## If the preview should move with the mouse.
var follow_mouse := true

const Painter = preload("res://addons/painter/painter.gd")
const Brush = preload("res://addons/painter/brush.gd")

var _painter : Painter
## An array of `SingleBrushPreviews`.
var _previews : Array
var _brush_preview_material := ShaderMaterial.new()

func _ready():
	appearance = appearance


func _input(event : InputEvent) -> void:
	if not is_instance_valid(_painter):
		return
	var brush : Brush = _painter.brush
	if not brush:
		return

	var pressure := 1.0
	if event is InputEventMouseMotion and event.button_mask == MOUSE_BUTTON_LEFT\
			and brush.size_pen_pressure:
		pressure = event.pressure
	var transforms : Array = _painter.get_brush_preview_transforms(
			get_viewport().get_mouse_position(), pressure, follow_mouse)
	
	# Add necessary amount of previews.
	while _previews.size() < transforms.size():
		var new := preload("single_brush_preview.tscn").instantiate()
		add_child(new)
		_previews.append(new)
	appearance = appearance

	# Remove excess previews.
	while _previews.size() > transforms.size():
		_previews.pop_front().queue_free()

	# Update transform and appearance.
	for transform_num in transforms.size():
		var preview : MeshInstance3D = _previews[transform_num]
		var material := preview.get_surface_override_material(0)
		var brush_transform : Transform3D = transforms[transform_num]
		if follow_mouse:
			preview.transform = brush_transform
		else:
			# Only apply rotation and scale.
			preview.transform.basis = preview.transform.basis.orthonormalized()\
					.scaled(brush_transform.basis.get_scale())
		if appearance == Appearance.BRUSH:
			material.set_shader_parameter("albedo", brush.get_texture(0))
			material.set_shader_parameter("color", brush.get_color(0))
			material.set_shader_parameter("tip", brush.tip)
