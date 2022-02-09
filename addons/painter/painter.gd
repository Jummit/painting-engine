extends Node

"""
Utility for painting meshes.

This class allows interatively painting multiple channels of the surface of a
3D meshes like albedo, normal etc. using various brush parameters.
It supports undo/redo, radial and mirrored symmetry, tangent-space painting,
erasing, size and angle jitter, follow path, clearing the results with colors
or textures and showing a brush preview by adding a `brush_preview.tscn`.

## Usage

```gdscript
painter.init(model, Vector2(1024, 1024), 4, brush, [Color.white])
painter.paint(Vector2(10, 10))
painter.finish_stroke()
var albedo = painter.get_result(0)
painter.cleanup()
```

All functions that take time yield and can be waited for like this:

```gdscript
yield(Awaiter.new(painter.redo()), "done")
```
"""

# TODO:
# Reimplement stencils
# Fix brush preview being too large when not over surface
# Screen-space painting
# Viewport-dependent size
# UV size
# No gaps when mouse moves fast
# Stroke smoothing
# Clone brush
# Color picking
# Backface painting
# Repainting with higher resolution
# Don't add full opacity in stroke
# Position jitter
# Clear texture folder on start
# Explicit surface selection

# Possibilities:
# Only render region and update with `VisualServer.texture_set_data_partial`.
# How to find out which areas are painted though?

signal paint_completed

var brush : Brush
var session : Array

# Emitted after the stored results are applied to the paint viewports.
signal _results_loaded

# Initial State

# The model being painted. The MeshInstance is used to determine the transform
# and mesh.
var _model : MeshInstance
# The size of the resulting texture. Preferably square with the width and hight
# being a power of two.
var _result_size : Vector2
var _undo_redo := UndoRedo.new()
# Util for saving and loading sets of textures to memory/disk.
# Used for undo/redo.
var _texture_store : TexturePackStore
# Utility texture used by the result shader to eliminate seams.
var _seams_texture : Texture
# The number of painting viewports available.
var _channels : int
# If `finish_stroke()` was called while a paint operation was in progress. If
# true, `finish_stroke()` will be called after the operation is completed.
var _finish_stroke_when_done : bool
# If a paint operation is in progress.
var _painting : bool

# Runtime State

# The set of textures that the model currently has applied.
var _current_pack : TexturePackStore.Pack
# While the stroke is not finished this stores where the user last painted.
var _last_transform : Transform
# Stores if the user successfully painted since the last stroke.
var _result_changed := false
# Next random size.
var _next_size := randf()
# Next random angle.
var _next_angle := randf()

# Path to the folder of textures used for undo/redo.
const TEXTURE_PATH := "user://undo_textures/{painter}"

const TexturePackStore = preload("utils/texture_pack_store.gd")
const Brush = preload("brush.gd")
const ChannelPainter = preload("channel_painter/channel_painter.gd")
const MultiYielder = preload("utils/multi_yielder.gd")
const Awaiter = preload("res://addons/painter/utils/awaiter.gd")
const CameraState = preload("res://addons/painter/camera_state.gd")
const PaintOperation = preload("res://addons/painter/paint_operation.gd")

onready var _channel_painters : Node = $ChannelPainters
onready var _collision_shape : CollisionShape = $ClickViewport/StaticBody/CollisionShape
onready var _click_viewport : Viewport = $ClickViewport
onready var _static_body : StaticBody = $ClickViewport/StaticBody
onready var _seams_generator : Node = $SeamsTextureGenerator

func _notification(what : int) -> void:
	if what == NOTIFICATION_PREDELETE:
		cleanup()


# Set up the painter using a mesh, the size of the painted textures, how many
# channels (textures) to paint, the brush and optionally an array of colors/
# textures that will be used as the starting texture.
# Should be called before doing anything else.
func init(model : MeshInstance, result_size : Vector2, channels := 1,
		initial_brush : Brush = null, start_values := []) -> void:
	_model = model
	brush = initial_brush
	_result_size = result_size
	_texture_store = TexturePackStore.new(
			TEXTURE_PATH.format({painter=str(get_instance_id())}))
	var shape := ConcavePolygonShape.new()
	shape.set_faces(_model.mesh.get_faces())
	_collision_shape.shape = shape
	_collision_shape.transform = _model.transform
	_seams_texture = yield(_seams_generator.generate(_model.mesh), "completed")
	reset_channels(channels)
	yield(Awaiter.new(clear_with(start_values)), "done")
	_current_pack = _store_results()


# Overrides the result of the channels using a list of colors/textures.
func clear_with(values : Array) -> void:
	_assert_ready()
	var yielder := MultiYielder.new()
	for channel in values.size():
		if values[channel]:
			yielder.add(Awaiter.new(_get_channel_painter(channel).clear_with(
					values[channel])), "done")
	yield(yielder, "all_completed")


# Returns the painted result of the given channel.
func get_result(channel : int) -> ViewportTexture:
	_assert_ready()
	assert(channel <= _channels, "Channel out of bounds: %s" % channel)
	var texture : ViewportTexture = _get_channel_painter(channel).get_result()
	texture.flags = Texture.FLAGS_DEFAULT
	return texture


# Paint on the model at the given `screen_pos` using the `brush`.
# Optionally the pen pressure can be provided.
func paint(screen_pos : Vector2, pressure := 1.0) -> void:
	_assert_ready()
	# Verify the brush transforms.
	var transforms := _get_brush_transforms(screen_pos, pressure)
	if not transforms:
		return
	if _last_transform and _last_transform.origin.distance_to(
			transforms.front().origin) < brush.spacing * brush.size\
			* (pressure if brush.size_pen_pressure else 1.0):
		return
	_next_angle = randf()
	_next_size = randf()
	_last_transform = transforms.front()
	yield(Awaiter.new(_do_paint(PaintOperation.new(CameraState.new(
			_model.get_viewport().get_camera()), _model.transform, screen_pos,
			brush.duplicate(), pressure))), "done")
	if _finish_stroke_when_done:
		finish_stroke()
		_finish_stroke_when_done = false


# Add a new stroke which can be undone using `undo`.
func finish_stroke() -> void:
	_assert_ready()
	_last_transform = Transform()
	if not _result_changed:
		return
	if _painting:
		_finish_stroke_when_done = true
		# Still wait for the result to be stored so this function can savely
		# be waited upon.
		yield(self, "_results_loaded")
	for channel in _channels:
		yield(Awaiter.new(_get_channel_painter(channel).finish_stroke()),
				"done")
	var thread := Thread.new()
	thread.start(self, "_store_results_threaded", thread)
	_result_changed = false
	yield(self, "_results_loaded")


# Redo the last paintstroke added by calling `finish_stroke`.
func undo() -> bool:
	_assert_ready()
	if _painting:
		return
	var result := _undo_redo.undo()
	yield(self, "_results_loaded")
	return result


# Redo the last paintstroke.
func redo() -> bool:
	_assert_ready()
	if _painting:
		return
	var result := _undo_redo.redo()
	yield(self, "_results_loaded")
	return result


# Replaces the old channels with a new set of empty painting channels.
func reset_channels(count : int) -> void:
	_assert_ready()
	_channels = count
	for channel_painter in _channel_painters.get_children():
		channel_painter.queue_free()
	for channel in _channels:
		var channel_painter := preload(
				"channel_painter/channel_painter.tscn").instance()
		_channel_painters.add_child(channel_painter)
		channel_painter.init(_model.mesh, _result_size, _seams_texture)


# Delete textures used for undo/redo from disk.
func cleanup() -> void:
	_assert_ready()
	_texture_store.cleanup()


# Starting from nothing, retrace the painting steps with the specified
# resolution. This could take a while.
func repaint(resolution : Vector2) -> void:
	_assert_ready()
	pass


# Assert that the painter was initialized before calling a method.
func _assert_ready() -> void:
	assert(_model, "Painter not initialized.")


# Painting

# Perform a paint operation.
func _do_paint(operation : PaintOperation) -> void:
	_painting = true
	var yielder := MultiYielder.new()
	for transform in _get_brush_transforms(operation.screen_position,
			operation.pressure):
		for channel in _channels:
			_get_channel_painter(channel).paint(brush, transform, operation)
			yielder.add(_get_channel_painter(channel), "paint_completed")
	yield(yielder, "all_completed")
	_result_changed = true
	_painting = false
	emit_signal("paint_completed")


# Returns the ChannelPainter of the given channel.
func _get_channel_painter(channel : int) -> ChannelPainter:
	return _channel_painters.get_child(channel) as ChannelPainter


# Brush Placement

# Returns the transforms for meshes that show where the brush would paint at a
# given screen position. Used by the brush preview.
func get_brush_preview_transforms(screen_pos : Vector2,
		pressure := 1.0, on_surface := true) -> Array:
	var transforms := _get_brush_transforms(screen_pos, pressure, true)
	if transforms and on_surface:
		return transforms
	return [Transform(_apply_brush_basis(
			_model.get_viewport().get_camera().transform.basis, pressure),
			_model.get_viewport().get_camera().project_position(screen_pos, 2))]


# Returns an empty array if the brush didn't hit the mesh.
# Pressure is required because it scales the transform if the brush is
# configured to do so.
func _get_brush_transforms(screen_pos : Vector2, pressure : float,
		preview := false) -> Array:
	# FIXME: This is a mess.
	var from := _model.get_viewport().get_camera().project_ray_origin(screen_pos)
	var to := from + _model.get_viewport().get_camera().project_ray_normal(
			screen_pos) * 100
	var result := _static_body.get_world()\
			.direct_space_state.intersect_ray(from, to)
	if not result:
		return []
	var z : Vector3 = result.normal
	var x := z.cross(Vector3.FORWARD if z.abs() == Vector3.UP else Vector3.UP)
	var y := x.cross(z)
	var transform := Transform(Basis(x, y, z).orthonormalized(),
			result.position + result.normal / 100.0)
	if brush.follow_path and not _last_transform and not preview:
		# Follow path can only work if one transform was already provided.
		# Because the preview should be displayed correctly when hovering
		# only return if the function was called by the painter.
		_last_transform = transform
		return []
	elif brush.follow_path and _last_transform\
			and transform.origin.x != _last_transform.origin.x:
		var follow_z := z
		var follow_x := _last_transform.origin.direction_to(result.position)
		var follow_y = x.cross(z) if follow_x.x > 0 else z.cross(x)
		transform.basis = Basis(follow_x, follow_y, follow_z).orthonormalized()
	transform.basis = _apply_brush_basis(transform.basis,
			pressure if brush.size_pen_pressure else 1)
	if (brush.symmetry) and (not brush.symmetry_axis):
		push_warning("Using symmetry but no symmetry axis set.")
	match brush.symmetry:
		Brush.Symmetry.MIRROR:
			var transforms := [transform]
			if brush.symmetry_axis.x:
				transforms = _get_mirrored(transforms, Basis.FLIP_X)
			if brush.symmetry_axis.y:
				transforms = _get_mirrored(transforms, Basis.FLIP_Y)
			if brush.symmetry_axis.z:
				transforms = _get_mirrored(transforms, Basis.FLIP_Z)
			return transforms
		Brush.Symmetry.RADIAL:
			var transforms := []
			for symmetry_num in brush.radial_symmetry_count:
				transforms.append(transform.rotated(brush.symmetry_axis,
						TAU / brush.radial_symmetry_count * symmetry_num))
			return transforms
	return [transform]


# Returns a basis that scales and rotates the brush transform according to the
# brush and the pressure.
func _apply_brush_basis(basis : Basis, pressure : float) -> Basis:
	return basis\
			.rotated(basis.z, brush.angle + brush.angle_jitter * _next_angle)\
			.scaled(Vector3.ONE * brush.size * (pressure + 0.1)\
				* lerp(1.0, _next_size, brush.size_jitter))


# Returns the given transform with its rotation and origin mirrored using a
# basis.
static func _get_mirrored(transforms : Array, flip_basis : Basis) -> Array:
	var new := transforms.duplicate()
	for transform in transforms:
		var new_transform : Transform = transform
		new_transform.origin = flip_basis * transform.origin
		new_transform.basis = flip_basis * transform.basis
		new.append(new_transform)
	return new


# Undo/Redo

# Perform `_store_results` on a thread as it uses slow file IO.
func _store_results_threaded(thread : Thread) -> void:
	var pack := _store_results()
	_undo_redo.create_action("Paintstroke")
	_undo_redo.add_do_method(self, "_load_results", pack)
	_undo_redo.add_undo_method(self, "_load_results", _current_pack)
	_undo_redo.commit_action()
	_current_pack = pack
	thread.call_deferred("wait_to_finish")


# Add the channel results in the texture store and return the new pack.
func _store_results() -> TexturePackStore.Pack:
	var results := []
	for channel in _channels:
		results.append(get_result(channel))
	return _texture_store.add_textures(results)


# Set the pack of textures as the current result. Emits `_result_loaded` when
# finished.
func _load_results(pack : TexturePackStore.Pack) -> void:
	_current_pack = pack
	yield(Awaiter.new(clear_with(pack.get_textures())), "done")
	emit_signal("_results_loaded")
