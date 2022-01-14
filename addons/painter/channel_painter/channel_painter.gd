extends Node

"""
Utility that is used by a painter to paint one channel.
The StrokeViewport holds the progress of a single stroke. When a stroke is
finished, it gets applied to the ResultViewport. This is required to support
stroke opacity.
"""

# Emitted once the entire painting queue has been completed.
signal paint_completed

# The brush that is used in the painting shader. Can be changed after the
# ChannelPainter is initialised.
var brush : Brush

var _paint_queue : Array
# If a paint stroke is being rendered.
var _busy := false
var _model : MeshInstance

const Brush = preload("../brush.gd")

onready var _result_viewport : Viewport = $ResultViewport
onready var _clear_texture_rect : TextureRect = $ResultViewport/ClearTextureRect
onready var _result_texture_rect : ColorRect = $ResultViewport/ResultTextureRect
onready var _clear_color_rect : ColorRect = $ResultViewport/ClearColorRect
onready var _mesh_instance : MeshInstance = $StrokeViewport/MeshInstance
onready var _stroke_viewport : Viewport = $StrokeViewport
onready var _camera : Camera = $StrokeViewport/Camera
onready var _stroke_material : ShaderMaterial = _mesh_instance.material_override
onready var _result_material : ShaderMaterial = _result_texture_rect.material

func init(model : MeshInstance, _size : Vector2, _brush : Brush,
		seams_texture : Texture):
	if not is_inside_tree():
		yield(self, "ready")
	_result_viewport.size = _size
	brush = _brush
	_model = model
	_mesh_instance.mesh = model.mesh
	_stroke_viewport.size = _size
	_stroke_material.set_shader_param("previous", _stroke_viewport.get_texture())
	_result_material.set_shader_param("seams", seams_texture)
	_result_material.set_shader_param("stroke", _stroke_viewport.get_texture())
	finish_stroke()


# Clears the result with a color or a texture.
func clear_with(value) -> void:
	if value is Texture:
		_clear_texture_rect.texture = value
	elif value is Color:
		# FIXME: alpha of transparent colors needs to be premultiplied
		_clear_color_rect.color = value
	_result_texture_rect.hide()
	# Clear to support transparent textures.
	_result_viewport.render_target_clear_mode =\
			Viewport.CLEAR_MODE_ONLY_NEXT_FRAME
	yield(VisualServer, "frame_post_draw")
	_result_viewport.render_target_update_mode = Viewport.UPDATE_ONCE
	yield(VisualServer, "frame_post_draw")
	_result_texture_rect.show()
	_clear_texture_rect.texture = null
	_clear_color_rect.color.a = 0
	yield(finish_stroke(), "completed")


func paint(transform : Transform, pressure : float, depth := 0) -> void:
	if depth > 500:
		# GDScript doesn't have tail call optimizations, so the depth of
		# recursion needs to be limited. Strokes this long shouldn't happen
		# anyway.
		_paint_queue.clear()
		return
	if _busy:
		_paint_queue.append([transform, pressure])
		return
	
	var model_camera := _model.get_viewport().get_camera()
	for member in ["far", "cull_mask", "fov", "frustum_offset", "h_offset",
			"keep_aspect", "near", "projection", "size", "v_offset"]:
		_camera[member] = model_camera[member]
	_mesh_instance.transform = _model.transform
	
	_stroke_material.set_shader_param("brush_transform", transform)
	var color := brush.get_color(get_index())
	color.a = brush.flow
	if brush.flow_pen_pressure:
		color.a = smoothstep(0.0, color.a, pressure * 2)
	_stroke_material.set_shader_param("brush_color", color)
	_stroke_material.set_shader_param("max_opacity", brush.stroke_opacity)
	_stroke_material.set_shader_param("albedo", brush.get_texture(get_index()))
	_stroke_material.set_shader_param("erase", brush.erase)
	_stroke_material.set_shader_param("tip", brush.tip)
	_stroke_material.set_shader_param("stencil", brush.stencil)
	_stroke_material.set_shader_param("stencil_transform", brush.stencil_transform)
	
	_result_material.set_shader_param("erase", brush.erase)
	
	_busy = true
	_stroke_viewport.render_target_update_mode = Viewport.UPDATE_ONCE
	yield(VisualServer, "frame_post_draw")
	# Wait for the stroke to be rendered before updating the result.
	_result_viewport.render_target_update_mode = Viewport.UPDATE_ONCE
	yield(VisualServer, "frame_post_draw")
	_busy = false
	if _paint_queue.size():
		var params : Array = _paint_queue.pop_front()
		var result = paint(params[0], params[1], depth + 1)
		while result is GDScriptFunctionState:
			result = yield(result, "completed")
	emit_signal("paint_completed")


# Apply the current stroke to the result.
func finish_stroke() -> void:
	if _busy:
		yield(self, "paint_completed")
	
	# To be able to add a new stroke ontop of the current result, a snapshot
	# has to be created and given to the result shader.
	var texture := ImageTexture.new()
	texture.create_from_image(_result_viewport.get_texture().get_data())
	_result_material.set_shader_param("previous", texture)
	
	# Clear the stroke viewport by hiding the mesh.
	_stroke_viewport.render_target_update_mode = Viewport.UPDATE_ONCE
	_mesh_instance.hide()
	yield(VisualServer, "frame_post_draw")
	_mesh_instance.show()


func get_result() -> ViewportTexture:
	return _result_viewport.get_texture()
