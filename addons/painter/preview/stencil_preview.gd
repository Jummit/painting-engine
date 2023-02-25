extends TextureRect

## An overlay that shows the stencil of a brush.

var brush: Brush

func _input(_event: InputEvent) -> void:
	if not brush:
		if visible:
			push_warning("Visible stencil preview doesn't have a brush assigned.")
		return
	texture = brush.stencil
	var transform := brush.stencil_transform
	material.set_shader_parameter("transform", transform)
