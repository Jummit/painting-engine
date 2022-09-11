extends Node

@onready var _mesh_instance : MeshInstance3D = $UVViewport/MeshInstance3D
@onready var _uv_viewport : SubViewport = $UVViewport
@onready var _seams_viewport : SubViewport = $SeamsViewport
@onready var _seams_rect : TextureRect = $SeamsViewport/SeamsRect

func generate(mesh : Mesh) -> ViewportTexture:
	_mesh_instance.mesh = mesh
	_uv_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	await RenderingServer.frame_post_draw
	var uv_mask := _uv_viewport.get_texture()
	_seams_rect.texture = uv_mask
	_seams_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	var seams_texture := _seams_viewport.get_texture()
	uv_mask.get_image().save_png("res://seams.png")
	return seams_texture
