extends Node

## Utility that is used by a painter to paint one channel.
##
## The StrokeViewport holds the progress of a single stroke. When a stroke is
## finished, it gets applied to the ResultViewport. This is required to support
## stroke opacity.

## Emitted once the entire painting queue has been completed.
signal paint_completed

var _paint_queue : Array
## If a paint stroke is being rendered.
var _busy := false

const Brush = preload("../brush.gd")
const CameraState = preload("res://addons/painter/camera_state.gd")
const PaintOperation = preload("res://addons/painter/paint_operation.gd")

@onready var _result_viewport : SubViewport = $ResultViewport
@onready var _clear_texture_rect : TextureRect = $ResultViewport/ClearTextureRect
@onready var _result_texture_rect : ColorRect = $ResultViewport/ResultTextureRect
@onready var _clear_color_rect : ColorRect = $ResultViewport/ClearColorRect
@onready var _mesh_instance : MeshInstance3D = $StrokeViewport/MeshInstance3D
@onready var _stroke_viewport : SubViewport = $StrokeViewport
@onready var _camera : Camera3D = $StrokeViewport/Camera3D
@onready var _stroke_material : ShaderMaterial = _mesh_instance.material_override
@onready var _result_material : ShaderMaterial = _result_texture_rect.material

func init(mesh : Mesh, _size : Vector2, seams_texture : Texture2D):
	if not is_inside_tree():
		await self.ready
	_result_viewport.size = _size
	_mesh_instance.mesh = mesh
	_stroke_viewport.size = _size
	_stroke_material.set_shader_parameter("previous", _stroke_viewport.get_texture())
	_result_material.set_shader_parameter("seams", seams_texture)
	_result_material.set_shader_parameter("stroke", _stroke_viewport.get_texture())
	finish_stroke()


## Clears the result with a color or a texture.
func clear_with(value) -> void:
	if value is Texture2D:
		_clear_texture_rect.texture = value
	elif value is Color:
		# FIXME: alpha of transparent colors needs to be premultiplied
		_clear_color_rect.color = value
	_result_texture_rect.hide()
	# Clear to support transparent textures.
	_result_viewport.render_target_clear_mode =\
			SubViewport.CLEAR_MODE_ONCE
	await RenderingServer.frame_post_draw
	_result_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	await RenderingServer.frame_post_draw
	_result_texture_rect.show()
	_clear_texture_rect.texture = null
	_clear_color_rect.color.a = 0
	await finish_stroke()


func paint(brush : Brush, transform : Transform3D, operation : PaintOperation,
		depth := 0) -> void:
	if depth > 500:
		# GDScript doesn't have tail call optimizations, so the depth of
		# recursion needs to be limited. Strokes this long shouldn't happen
		# anyway.
		return _paint_queue.clear()
	if _busy:
		return _paint_queue.append([brush, transform, operation])
	
	operation.camera_state.apply(_camera)
	_mesh_instance.transform = operation.model_transform
	
	_stroke_material.set_shader_parameter("brush_transform", transform)
	var color := brush.get_color(get_index())
	color.a = brush.flow
	if brush.flow_pen_pressure:
		color.a = smoothstep(0.0, color.a, operation.pressure * 2)
	_stroke_material.set_shader_parameter("brush_color", color)
	_stroke_material.set_shader_parameter("max_opacity", brush.stroke_opacity)
	_stroke_material.set_shader_parameter("albedo", brush.get_texture(get_index()))
	_stroke_material.set_shader_parameter("erase", brush.erase)
	_stroke_material.set_shader_parameter("tip", brush.tip)
	_stroke_material.set_shader_parameter("stencil", brush.stencil)
	_stroke_material.set_shader_parameter("stencil_transform", brush.stencil_transform)
	
	_result_material.set_shader_parameter("erase", brush.erase)
	
	_busy = true
	_stroke_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	await RenderingServer.frame_post_draw
	# Wait for the stroke to be rendered before updating the result.
	_result_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	await RenderingServer.frame_post_draw
	_busy = false
	if not _paint_queue.is_empty():
		await callv("paint", _paint_queue.pop_front() + [depth + 1])
	emit_signal("paint_completed")


## Apply the current stroke to the result.
func finish_stroke() -> void:
	if _busy:
		await self.paint_completed
	
	# To be able to add a new stroke ontop of the current result, a snapshot
	# has to be created and given to the result shader.
	_result_material.set_shader_parameter("previous",
			ImageTexture.create_from_image(_result_viewport.get_texture().get_image()))
	
	# Clear the stroke viewport by hiding the mesh.
	_stroke_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	_mesh_instance.hide()
	await RenderingServer.frame_post_draw
	_mesh_instance.show()


func get_result() -> ViewportTexture:
	return _result_viewport.get_texture()


#func _paint_multiple(brushes : Array, transforms : Array,
#		operations : Array) -> void:
#	operation.camera_state.apply(_camera)
#	_mesh_instance.transform = operation.model_transform
#
#	_stroke_material.set_shader_parameter("brush_transform", transform)
#	var color := brush.get_color(get_index())
#	color.a = brush.flow
#	if brush.flow_pen_pressure:
#		color.a = smoothstep(0.0, color.a, operation.pressure * 2)
#	_stroke_material.set_shader_parameter("brush_color", color)
#	_stroke_material.set_shader_parameter("max_opacity", brush.stroke_opacity)
#	_stroke_material.set_shader_parameter("albedo", brush.get_texture(get_index()))
#	_stroke_material.set_shader_parameter("erase", brush.erase)
#	_stroke_material.set_shader_parameter("tip", brush.tip)
#	_stroke_material.set_shader_parameter("stencil", brush.stencil)
#	_stroke_material.set_shader_parameter("stencil_transform", brush.stencil_transform)
#
#	_result_material.set_shader_parameter("erase", brush.erase)
#
#	_busy = true
#	_stroke_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
#	await RenderingServer.frame_post_draw
#	# Wait for the stroke to be rendered before updating the result.
#	_result_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
#	await RenderingServer.frame_post_draw
#	_busy = false
#	if not _paint_queue.is_empty():
#		yield(Awaiter.new(callv("paint",
#				_paint_queue.pop_front() + [depth + 1])), "done")
#	emit_signal("paint_completed")
