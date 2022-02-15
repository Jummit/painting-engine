extends TextureRect

"""
An overlay that shows the stencil of a brush.
"""

export var painter := NodePath("../Painter") setget _set_painter

var _painter : Painter

const Painter = preload("res://addons/painter/painter.gd")
const Brush = preload("res://addons/painter/brush.gd")

func _ready():
	_set_painter(painter)


func _input(_event: InputEvent) -> void:
	if not is_instance_valid(_painter):
		return
	var brush : Brush = _painter.brush
	if not brush:
		return
	texture = brush.stencil
	material.set_shader_param("transform", brush.stencil_transform)


func _set_painter(to):
	painter = to
	if to:
		_painter = get_node(painter)
