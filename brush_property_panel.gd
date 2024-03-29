extends "res://addons/property_panel/property_panel.gd"

## Panel exposing brush properties.

var _editable_brush : EditableBrush

const SYMMETRY_AXIS := {
	none = Vector3.ZERO,
	x = Vector3.RIGHT,
	y = Vector3.UP,
	z = Vector3.FORWARD,
}

const Brush = preload("addons/painter/brush.gd")

class EditableBrush:
	var brush: Brush

	func _init(_brush):
		brush = _brush
	
	static func load_texture(path: String) -> Texture2D:
		if not FileAccess.file_exists(path):
			return null
		if ResourceLoader.exists(path):
			return load(path)
		return ImageTexture.create_from_image(Image.load_from_file(path))
	
	func _set(property: StringName, value) -> bool:
		match str(property):
			"color":
				# TODO: Maybe expose all channels.
				brush.colors = [value, value, value, Color(0.5, 0.5, 1.0)]
			"texture":
				var texture := EditableBrush.load_texture(value)
				if texture:
					brush.textures = [texture]
				else:
					brush.textures = []
			"stencil":
				brush.stencil = EditableBrush.load_texture(value)
			"symmetry":
				brush.symmetry = Brush.Symmetry[value]
			"symmetry_axis":
				brush.symmetry_axis = SYMMETRY_AXIS[value]
			"projection":
				brush.projection = Brush.BrushProjection[value]
			"size_space":
				brush.size_space = Brush.SizeSpace[value]
			"tip":
				brush.tip = EditableBrush.load_texture(value)
			_:
				if property in brush:
					brush[property] = value
				else:
					return false
		return true

	func _get(property: StringName):
		match str(property):
			"color":
				return brush.get_color(0)
			"texture":
				return brush.get_texture(0)
			"stencil":
				@warning_ignore("incompatible_ternary")
				return null if not brush.stencil else brush.stencil.resource_path
			"symmetry":
				return Brush.Symmetry.keys()[brush.symmetry]
			"symmetry_axis":
				return SYMMETRY_AXIS.values()[SYMMETRY_AXIS.values().find(brush.symmetry_axis)]
			"projection":
				return Brush.BrushProjection.keys()[brush.projection]
			"size_space":
				return Brush.SizeSpace.keys()[brush.size_space]
			"tip":
				return "" if not brush.tip else brush.tip.resource_path
			_:
				return brush.get(property)


func _ready() -> void:
	super._ready()
	set_properties([
		"Texture2D",
		Properties.FilePathProperty.new("tip"),
		Properties.FilePathProperty.new("texture"),
		Properties.ColorProperty.new("color"),
		Properties.BoolProperty.new("follow_path"),
		Properties.FloatProperty.new("spacing", 0, 1),
		Properties.FloatProperty.new("angle", 0, 1),
		"Flow/Opacity",
		Properties.FloatProperty.new("stroke_opacity", 0, 1),
		Properties.FloatProperty.new("flow", 0, 1),
		Properties.BoolProperty.new("flow_pen_pressure"),
		Properties.BoolProperty.new("size_pen_pressure"),
		"Randomness",
		Properties.FloatProperty.new("angle_jitter", 0, 1),
		Properties.FloatProperty.new("size_jitter", 0, 1),
		Properties.FloatProperty.new("position_jitter", 0, 1),
		"Symmetry",
		Properties.EnumProperty.new("symmetry", Brush.Symmetry.keys()),
		Properties.EnumProperty.new("symmetry_axis", SYMMETRY_AXIS.keys()),
		Properties.IntProperty.new("radial_symmetry_count", 2, 12),
		"Misc",
		Properties.EnumProperty.new("projection", Brush.BrushProjection.keys()),
		Properties.EnumProperty.new("size_space", Brush.SizeSpace.keys()),
		Properties.FilePathProperty.new("stencil"),
	])


func load_brush(brush : Brush) -> void:
	_editable_brush = EditableBrush.new(brush)
	load_values(_editable_brush)


func _on_property_changed(_property, _value) -> void:
	store_values(_editable_brush)
