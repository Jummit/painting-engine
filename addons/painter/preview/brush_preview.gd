extends Spatial

"""
Interactive in-viewport brush peview.

Uses the tip and first texture and color to show a preview of what the brush
looks like.
"""

enum Appearance {
	# A preview of what the brush will paint.
	BRUSH,
	# A neutral black-and-white striped circle.
	CIRCLE,
}

export(Appearance) var appearance := Appearance.BRUSH setget _set_appearance
export var painter := NodePath("../Painter") setget _set_painter

# If the preview should move with the mouse.
var follow_mouse := true

var _painter : Painter
# An array of `SingleBrushPreviews`.
var _previews : Array
var _brush_preview_material := ShaderMaterial.new()

const Painter = preload("res://addons/painter/painter.gd")
const Brush = preload("res://addons/painter/brush.gd")

func _ready():
	_set_appearance(appearance)


func _input(event : InputEvent) -> void:
	if not is_instance_valid(_painter):
		return
	var brush : Brush = _painter.brush
	if not brush:
		return

	var pressure := 1.0
	if event is InputEventMouseMotion and event.button_mask == BUTTON_LEFT\
			and brush.size_pen_pressure:
		pressure = event.pressure
	var transforms : Array = _painter.get_brush_preview_transforms(
			get_viewport().get_mouse_position(), pressure, follow_mouse)
	
	# Add necessary amount of previews.
	while _previews.size() < transforms.size():
		var new := preload("single_brush_preview.tscn").instance()
		add_child(new)
		_previews.append(new)
	_set_appearance(appearance)

	# Remove excess previews.
	while _previews.size() > transforms.size():
		_previews.pop_front().queue_free()

	# Update transform and appearance.
	for transform_num in transforms.size():
		var preview : MeshInstance = _previews[transform_num]
		var material := preview.get_surface_material(0)
		var brush_transform : Transform = transforms[transform_num]
		if follow_mouse:
			preview.transform = brush_transform
		else:
			# Only apply rotation and scale.
			preview.transform.basis = preview.transform.basis.orthonormalized()\
					.scaled(brush_transform.basis.get_scale())
		if appearance == Appearance.BRUSH:
			material.set_shader_param("albedo", brush.get_texture(0))
			material.set_shader_param("color", brush.get_color(0))
			material.set_shader_param("tip", brush.tip)


func _set_appearance(to):
	appearance = to
	for preview in _previews:
		preview.set_surface_material(0, preload("brush_preview.material") if\
				appearance == Appearance.BRUSH else\
				preload("circle_preview.material"))


func _set_painter(to):
	painter = to
	if to:
		_painter = get_node(painter)

