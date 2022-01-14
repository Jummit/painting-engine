extends Node

onready var _mesh_instance : MeshInstance = $UVViewport/MeshInstance
onready var _uv_viewport : Viewport = $UVViewport
onready var _seams_viewport : Viewport = $SeamsViewport
onready var _seams_rect : TextureRect = $SeamsViewport/SeamsRect

func generate(mesh : Mesh) -> Texture:
	_mesh_instance.mesh = mesh
	_uv_viewport.render_target_update_mode = Viewport.UPDATE_ONCE
	yield(VisualServer, "frame_post_draw")
	var uv_mask := _uv_viewport.get_texture()
	uv_mask.flags = Texture.FLAG_FILTER
	_seams_rect.texture = uv_mask
	_seams_viewport.render_target_update_mode = Viewport.UPDATE_ONCE
	var seams_texture := _seams_viewport.get_texture()
	seams_texture.flags = Texture.FLAG_FILTER
	return seams_texture
