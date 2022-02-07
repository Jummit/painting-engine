extends Reference

const Brush = preload("brush.gd")
const CameraState = preload("camera_state.gd")

var camera_state : CameraState
var model_transform : Transform
var screen_position : Vector2
var brush : Brush
var pressure : float

func _init(_camera_state : CameraState, _model_transform : Transform,
		_screen_position : Vector2, _brush : Brush, _pressure : float) -> void:
	camera_state = _camera_state
	model_transform = _model_transform
	screen_position = _screen_position
	brush = _brush
	pressure = _pressure

