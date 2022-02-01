extends Reference
# warning-ignore-all:unused_class_variable

"""
Brush settings.
"""

enum Projection {
	SCREEN_SPACE,
	SURFACE_SPACE,
}

enum Symmetry {
	NONE,
	MIRROR,
	RADIAL,
}

# The scale of the brush tip.
var size := 1.0
# The projection which projects the mouse position into brush space.
var projection : int = Projection.SCREEN_SPACE
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

