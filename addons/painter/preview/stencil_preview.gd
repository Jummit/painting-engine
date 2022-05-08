extends TextureRect

## An overlay that shows the stencil of a brush.

@export var painter := NodePath("../Painter"):
	set(to):
		painter = to
		if to:
			_painter = get_node(painter)

const Painter = preload("res://addons/painter/painter.gd")

var _painter : Painter
const Brush = preload("res://addons/painter/brush.gd")

func _ready():
	painter = painter


func _input(_event: InputEvent) -> void:
	if not is_instance_valid(_painter):
		return
	var brush : Brush = _painter.brush
	if not brush:
		return
	texture = brush.stencil
	var transform := brush.stencil_transform
	material.set_shader_param("transform", transform)
