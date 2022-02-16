extends Reference
# warning-ignore-all:unused_class_variable

"""
Brush settings.
"""

enum Projection {
	# The brush is projected from the camera view.
	SCREEN_SPACE,
	# The brush is projected into the tangent space of the mesh.
	SURFACE_SPACE,
}

enum Symmetry {
	# No symmetry.
	NONE,
	# The brush is mirrored on each non-null axis of `symmetry_axis`.
	MIRROR,
	# The brush is rotated around the `symmetry_axis`. The amount is specified
	# by `radial_symmetry_count`.
	RADIAL,
}

# The scale of the brush tip.
var size := 1.0
# The projection which projects the mouse position into brush space.
var projection : int = Projection.SURFACE_SPACE
# If the result should be removed by the opacity of the stroke.
var erase := false
# The texture of each channel.
var textures : Array
# The color each channel ist tintet.
var colors : Array
# The scale of the textures.
var pattern_scale := 1.0
# If the size of the tip is affected by pen pressure.
var size_pen_pressure := false
# If the opacity of the tip is affected by pen pressure.
var flow_pen_pressure := false
# The opacity of a single brush.
var flow := 1.0
# The maximimum opacity of a single brush strokes.
var stroke_opacity := 1.0
# The randomness of the size of the brush.
var size_jitter := 0.0
# The random offset of the painting position.
var position_jitter := 0.0
# The type of symmetry to use.
var symmetry : int = Symmetry.NONE
# An axis is enabled if it is anything other than zero.
# This is used as the axis for radial symmetry.
var symmetry_axis : Vector3
# The amount of symmetry axis.
var radial_symmetry_count := 2
# The randomness of the angle.
var angle_jitter := 0.0
# The minimum distance between dots.
var spacing := 0.3
# The angle of the brush tip.
var angle := 0.0
# If the angle of the tip should point from the last brush stroke to the next.
# If the angle isn't zero, it is added ontop of that.
var follow_path := false
# The texture that determines the opacity of the stroke.
var tip : Texture

# A screen-space texture which opacity is multiplied by the strength of the
# stroke.
var stencil : Texture
# The stencil transform in view-space.
var stencil_transform : Transform2D

# Returns the color a channel texture is tintet, white if not specified.
func get_color(channel : int) -> Color:
	return Color.white if colors.size() <= channel or not colors[channel] else colors[channel]


# Returns the texture a channel texture is tintet, white if not specified.
func get_texture(channel : int) -> Texture:
	return null if textures.size() <= channel else textures[channel]


# Returns a new brush with the same settings.
func duplicate() -> Object:
	return dict2inst(inst2dict(self))


# Returns the list of transforms that result when the given transform is
# mirrored using this brush's symmetry options.
func apply_symmetry(transform : Transform) -> Array:
	if symmetry and not symmetry_axis:
		push_warning("Using symmetry but no symmetry axis is set.")
	match symmetry:
		Symmetry.MIRROR:
			var transforms := [transform]
			if symmetry_axis.x:
				transforms = _get_mirrored(transforms, Basis.FLIP_X)
			if symmetry_axis.y:
				transforms = _get_mirrored(transforms, Basis.FLIP_Y)
			if symmetry_axis.z:
				transforms = _get_mirrored(transforms, Basis.FLIP_Z)
			return transforms
		Symmetry.RADIAL:
			var transforms := []
			for symmetry_num in radial_symmetry_count:
				var angle : float = TAU / radial_symmetry_count * symmetry_num
				var rotated := transform.rotated(symmetry_axis, angle)
				transforms.append(rotated)
			return transforms
	return [transform]


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
