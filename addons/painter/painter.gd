extends Node
class_name Painter

## Utility for painting meshes.
##
## This class allows interatively painting multiple channels of the surface of a
## 3D meshes like albedo, normal etc. using various brush parameters.
## It supports undo/redo, radial and mirrored symmetry, tangent-space painting,
## erasing, size and angle jitter, follow path, clearing the results with colors
## or textures and showing a brush preview by adding a [code]brush_preview.tscn[/code].
## 
## [b]Usage[/b]
## 
## [codeblock]
## painter.init(model, Vector2(1024, 1024), 4, brush, [Color.WHITE])
## painter.paint(Vector2(10, 10))
## painter.finish_stroke()
## var albedo = painter.get_result(0)
## painter.cleanup()
## [/codeblock]

## TODO:
# UV size
# Stroke leaves artifact
# Clone brush
# Color picking
# Backface painting
# Screen-space painting
# Reimplement stencils
# Clicking after brush adjust paints
# Repainting with higher resolution
# Better seams. there must be a way
# Position jitter
# Make some sort of diagram showing the process from input -> viewport
# Explicit surface selection
# Make seam generation optional
# Use multistroke for symmetry
# Blend modes
# Do something when paint queue is overflowed
# Test with multiple surfaces
# Add more maps in the demo
# Scrolling options zooms in
# Use scene unique names and class_name

## Possibilities:
# Stroke smoothing
# Documentation, maybe on GH pages?
# Usage in games?
# Randomized brush texture
# Put in some asset library
# Shapes: Lines, Squares, Circles...
# Persistent undo-redo
# Only render region and update with `texture_set_data_partial`.
# -> How to find out which areas are painted though?

const TexturePackStore = preload("utils/texture_pack_store.gd")
const ChannelPainter = preload("channel_painter/channel_painter.gd")
const CameraState = preload("camera_state.gd")
const PaintOperation = preload("paint_operation.gd")

## Emitted after the stored results are applied to the paint viewports.
signal _results_loaded
signal _paint_completed

# Initial State

## The model being painted. The MeshInstance3D is used to determine the transform
## and mesh.
var _model : MeshInstance3D
## The size of the resulting texture. Preferably square with the width and hight
## being a power of two.
var _result_size : Vector2
var _undo_redo : UndoRedo
## Util for saving and loading sets of textures to memory/disk.
## Used for undo/redo.
var _texture_store : TexturePackStore
## Utility texture used by the result shader to eliminate seams.
var _seams_texture : Texture2D
## The number of painting viewports available.
var _channels : int

# Runtime State

## The set of textures that the model currently has applied.
var _current_pack : TexturePackStore.Pack
## While the stroke is not finished this stores where the user last painted.
var _last_transform : Transform3D
## Stores if the user successfully painted since the last stroke.
var _result_stored := false
## Next random size.
var _next_size := randf()
## Next random angle.
var _next_angle := randf()
## List of paint operations.
var _session : Array
## The paint operations of the current stroke.
var _stroke_operations : Array
# If a paint operation is in progress.
var _painting : bool
var _paint_queue: Array[PaintOperation]
var _last_screen_pos: Vector2

## Path to the folder of textures used for undo/redo.
const TEXTURE_PATH := "user://undo_textures/painter_{painter}"

const _MAX_STROKES_PER_OPERATION := 10

@onready var _channel_painters : Node = $ChannelPainters
@onready var _collision_shape : CollisionShape3D = $ClickViewport/StaticBody3D/CollisionShape3D
@onready var _click_viewport : SubViewport = $ClickViewport
@onready var _static_body : StaticBody3D = $ClickViewport/StaticBody3D
@onready var _seams_generator : Node = $SeamsTextureGenerator

func _notification(what : int) -> void:
	if what == NOTIFICATION_PREDELETE:
		cleanup()


## Set up the painter using a mesh, the size of the painted textures, how many
## channels (textures) to paint, the brush and optionally an array of colors/
## textures that will be used as the starting texture.
## Should be called before doing anything else.
func init(model : MeshInstance3D, result_size := Vector2(1024, 1024),
		channels := 1, undo_redo := UndoRedo.new()) -> void:
	_model = model
	_result_size = result_size
	_texture_store = TexturePackStore.new(TEXTURE_PATH.format({painter=get_instance_id()}))
	_undo_redo = undo_redo
	_texture_store.clear()
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(_model.mesh.get_faces())
	_collision_shape.shape = shape
	_collision_shape.transform = _model.transform
	_seams_texture = await _seams_generator.generate(_model.mesh)
	reset_channels(channels)
	_current_pack = _store_results()


## Overrides the result of the channels using a list of colors/textures.
func clear_with(values : Array) -> void:
	_assert_ready()
	for channel in values.size():
		if values[channel]:
			var channel_painter := _get_channel_painter(channel)
			await channel_painter.clear_with(values[channel])
	_current_pack = _store_results()


## Returns the painted result of the given channel.
func get_result(channel : int) -> ViewportTexture:
	_assert_ready()
	assert(channel <= _channels, "Channel out of bounds")
	var texture := _get_channel_painter(channel).get_result()
	return texture


## Paint on the model at the given `screen_pos` using the [brush].
## Optionally the pen pressure can be provided.
func paint(screen_pos : Vector2, brush : Brush, pressure := 1.0) -> void:
	_assert_ready()
	_last_screen_pos = screen_pos
	# Verify the brush transforms.
	var transforms := _get_brush_transforms(screen_pos, pressure, brush)
	if transforms.is_empty():
		return
	var distance_to_last := _last_transform.origin.distance_to(
			transforms.front().origin)
	var minimum_spacing := brush.spacing * transforms[0].basis.x.length()
	if brush.size_pen_pressure:
		minimum_spacing *= pressure
	if _last_transform != Transform3D() and distance_to_last < minimum_spacing:
		return
	_next_angle = randf()
	_next_size = randf()
	_last_transform = transforms.front()
	var operations: Array[PaintOperation] = []
	for transform in transforms:
		operations.append(PaintOperation.new(CameraState.new(
				_model.get_viewport().get_camera_3d()), 
				_model.transform, screen_pos,
				brush.duplicate(), pressure, transform))
	await _do_paint(operations)
	_paint_completed.emit()


## Paint a line from the last painted position to the given position.
func paint_to(screen_pos : Vector2, brush : Brush, pressure := 1.0) -> void:
	# TODO: what should pressure be here
	var current_last = _last_screen_pos
	for i in 50:
		paint(current_last.lerp(screen_pos, i / 50.0), brush, pressure)


## Add a new stroke which can be undone using [method]undo[/method].
func finish_stroke() -> void:
	_assert_ready()
	_last_transform = Transform3D()
	if _result_stored:
		return
	if _painting:
		await _paint_completed
	for channel in _channels:
		_get_channel_painter(channel).start_finishing_stroke()
	await RenderingServer.frame_post_draw
	for channel in _channels:
		_get_channel_painter(channel).complete_finishing_stroke()
	var thread := Thread.new()
	thread.start(_create_stroke_action.bind(thread))
	_result_stored = true
	await _results_loaded


## Redo the last paintstroke added by calling `finish_stroke`.
func undo() -> bool:
	_assert_ready()
	if _painting:
		return false
	var result := _undo_redo.undo()
	await _results_loaded
	return result


## Redo the last paintstroke.
func redo() -> bool:
	_assert_ready()
	if _painting:
		return false
	var result := _undo_redo.redo()
	await self._results_loaded
	return result


## Replaces the old channels with a new set of empty painting channels.
func reset_channels(count : int) -> void:
	_assert_ready()
	_channels = count
	for channel_painter in _channel_painters.get_children():
		channel_painter.queue_free()
	for channel in _channels:
		var channel_painter := preload(
				"channel_painter/channel_painter.tscn").instantiate()
		_channel_painters.add_child(channel_painter)
		channel_painter.init(_model.mesh, _result_size, _seams_texture)


## Delete textures used for undo/redo from disk.
func cleanup() -> void:
	_assert_ready()
	_texture_store.clear()


## Starting from nothing, retrace the painting steps with the specified
## resolution. This could take a while.
func repaint(resolution : Vector2) -> void:
	_assert_ready()
	pass


## Assert that the painter was initialized before calling a method.
func _assert_ready() -> void:
	assert(_model, "Painter not initialized.")


### Painting ###

## Perform a paint operation.
func _do_paint(operations : Array[PaintOperation]) -> void:
	if _painting:
		_paint_queue.append_array(operations)
		return
	_painting = true
	_stroke_operations += operations
	for channel in _channels:
		_get_channel_painter(channel).paint(operations)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	_result_stored = false
	_painting = false
	if not _paint_queue.is_empty():
		var next : Array[PaintOperation] = []
		for i in min(_MAX_STROKES_PER_OPERATION, _paint_queue.size()):
			next.append(_paint_queue.pop_front())
		await _do_paint(next)


## Returns the ChannelPainter of the given channel.
func _get_channel_painter(channel : int) -> ChannelPainter:
	return _channel_painters.get_child(channel) as ChannelPainter


# Brush Placement

## Returns the transforms for meshes that show where the brush would paint at a
## given screen position. Used by the brush preview.
func get_brush_preview_transforms(screen_pos : Vector2, brush : Brush,
		pressure := 1.0, on_surface := true) -> Array:
	var transforms := _get_brush_transforms(screen_pos, pressure, brush, true)
	if not transforms.is_empty() and on_surface:
		return transforms
	var camera := _model.get_viewport().get_camera_3d()
	var basis := _apply_brush_basis(camera.transform.basis, pressure, brush)
	var position := camera.project_position(screen_pos, 2)
	return [Transform3D(basis, position)]


## Returns an empty array if the brush didn't hit the mesh.
## Pressure is required because it scales the transform if the brush is
## configured to do so.
func _get_brush_transforms(screen_pos : Vector2, pressure : float,
		brush : Brush, preview := false) -> Array[Transform3D]:
	var hit := _cast_ray(screen_pos)
	var transform := _get_transform_from_hit(hit)
	if transform == Transform3D():
		return []
	if brush.follow_path:
		if _last_transform == Transform3D() and not preview:
			# Follow path can only work if one transform was already provided.
			# Because the preview should be displayed correctly when hovering
			# only return if the function was called by the painter.
			_last_transform = transform
			return []
		elif _last_transform != Transform3D() and transform.origin.x != _last_transform.origin.x:
			var z := transform.basis.z
			var y := -_last_transform.origin.direction_to(transform.origin)
			var x = y.cross(z) if y.y > 0 else z.cross(y)
			transform.basis = Basis(x, y, z).orthonormalized()
	if brush.size_space == Brush.SizeSpace.SCREEN:
		var camera := _model.get_viewport().get_camera_3d()
		transform.basis = transform.basis.scaled(
				Vector3.ONE * camera.position.distance_to(hit.position) / 10.0)
	transform.basis = _apply_brush_basis(transform.basis, pressure, brush)
	return brush.apply_symmetry(transform)


func _cast_ray(screen_pos : Vector2) -> Dictionary:
	var camera := _model.get_viewport().get_camera_3d()
	var from := camera.project_ray_origin(screen_pos)
	var to := from + camera.project_ray_normal(screen_pos) * 100
	var ray := PhysicsRayQueryParameters3D.new()
	ray.from = from
	ray.to = to
	return _static_body.get_world_3d().direct_space_state.intersect_ray(ray)


## Returns the surface-space transform on the given screen position.
func _get_transform_from_hit(result : Dictionary) -> Transform3D:
	if result.is_empty():
		return Transform3D()
	var z : Vector3 = result.normal
	var x := z.cross(Vector3.FORWARD if z.abs() == Vector3.UP else Vector3.UP)
	# Negate here so the brush texture is upright.
	var y := -x.cross(z)
	var basis := Basis(x, y, z).orthonormalized()
	var origin : Vector3 = result.position + result.normal / 100.0
	return Transform3D(basis, origin)


## Returns a basis that points from a given point to another, keeping forward
## the z axis.
static func _get_basis_pointed_towards(from : Vector3, to : Vector3,
		forward : Vector3) -> Basis:
	var z := forward
	var x := from.direction_to(to)
	var y = x.cross(z) if x.x > 0 else z.cross(x)
#	var x := from.direction_to(to)
#	var y = x.cross(z) if x.x > 0 else z.cross(x)
	return Basis(x, y, z).orthonormalized()


## Returns a basis that scales and rotates the brush transform according to the
## brush and the pressure.
func _apply_brush_basis(basis : Basis, pressure : float, brush : Brush) -> Basis:
	var random_scale : float = lerp(1.0, _next_size, brush.size_jitter)
	var scale := brush.size
	if brush.size_pen_pressure:
		scale *= (pressure + 0.1)
	var random_angle : float = brush.angle_jitter * _next_angle
	return basis\
			.rotated(basis.z.normalized(), brush.angle + random_angle)\
			.scaled(Vector3.ONE * scale * random_scale)


### Undo/Redo ##

## Append the operations
func _store_operations(operations : Array) -> void:
	_session += operations


## Remove the given number of operations from the session.
func _remove_operations(count : int) -> void:
	_session.resize(_session.size() - count)


## Create a stroke action which stores the results so they can be applied when
## the stroke is undone. Perform [_store_results] on a thread as it uses slow
## file IO.
func _create_stroke_action(thread : Thread) -> void:
	_undo_redo.create_action("Paintstroke")
	_undo_redo.add_do_method(_store_operations.bind(_stroke_operations))
	_undo_redo.add_undo_method(_remove_operations.bind(_stroke_operations.size()))
	var pack := _store_results()
	_undo_redo.add_do_method(_load_results.bind(pack))
	_undo_redo.add_undo_method(_load_results.bind(_current_pack))
	_undo_redo.commit_action()
	thread.call_deferred("wait_to_finish")


## Add the channel results in the texture store and return the new pack.
func _store_results() -> TexturePackStore.Pack:
	var results := []
	for channel in _channels:
		results.append(get_result(channel))
	return _texture_store.add_textures(results)


## Set the pack of textures as the current result. Emits [_result_loaded] when
## finished so it can be awaited when used inside a thread or [UndoRedo] call.
func _load_results(pack) -> void:# : TexturePackStore.Pack) -> void:
	if pack != _current_pack:
		_current_pack = pack
		await clear_with(pack.get_textures())
	emit_signal("_results_loaded")
