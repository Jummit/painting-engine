extends Node

## Utility that is used by a painter to paint one channel.
##
## The StrokeViewport holds the progress of a single stroke. When a stroke is
## finished, it gets applied to the ResultViewport. This is required to support
## stroke opacity.

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
	await finish_stroke()


## Clears the result with a color or a texture.
func clear_with(value) -> void:
	if value is Texture2D:
		_clear_texture_rect.texture = value
	elif value is Color:
		# TODO: alpha of transparent colors needs to be premultiplied
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


func paint(operations : Array[PaintOperation]) -> void:
	operations.front().camera_state.apply(_camera)
	_mesh_instance.transform = operations.front().model_transform
	var brush : Brush = operations.front().brush
	
	var transforms: Array[Transform3D] = operations.map(
			func(o): return o.brush_transform)
	_stroke_material.set_shader_parameter("brush_transforms",
			_mat_to_float_array(transforms))
	var color := brush.get_color(get_index())
	color.a = brush.flow
	if brush.flow_pen_pressure:
		color.a = smoothstep(0.0, color.a, operations.front().pressure * 2)
	_stroke_material.set_shader_parameter("strokes", operations.size())
	_stroke_material.set_shader_parameter("brush_color", color)
	_stroke_material.set_shader_parameter("max_opacity", brush.stroke_opacity)
	_stroke_material.set_shader_parameter("albedo", brush.get_texture(get_index()))
	_stroke_material.set_shader_parameter("erase", brush.erase)
	_stroke_material.set_shader_parameter("tip", brush.tip)
	_stroke_material.set_shader_parameter("stencil_transform", brush.stencil_transform)
	
	_result_material.set_shader_parameter("erase", brush.erase)
	
	_stroke_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	await RenderingServer.frame_post_draw
	_result_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	await RenderingServer.frame_post_draw


static func _mat_to_float_array(transforms: Array[Transform3D]) -> PackedFloat32Array:
	var ar: PackedFloat32Array = []
	for t in transforms:
		ar += PackedFloat32Array([t.basis.x.x, t.basis.x.y, t.basis.x.z,
				0,
				t.basis.y.x, t.basis.y.y, t.basis.y.z,
				0,
				t.basis.z.x, t.basis.z.y, t.basis.z.z,
				0,
				t.origin.x, t.origin.y, t.origin.z, 1])
	return ar


## Apply the current stroke to the result.
func finish_stroke() -> void:
	# To be able to add a new stroke ontop of the current result, a snapshot
	# has to be created and given to the result shader.
	_result_material.set_shader_parameter("previous",
			ImageTexture.create_from_image(
			_result_viewport.get_texture().get_image()))
	
	# Clear the stroke viewport by hiding the mesh.
	_stroke_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	_mesh_instance.hide()
	await RenderingServer.frame_post_draw
	_mesh_instance.show()


func get_result() -> ViewportTexture:
	return _result_viewport.get_texture()
