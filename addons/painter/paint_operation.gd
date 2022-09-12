extends RefCounted

## All information that is needed to perform a paint operation

## Used to record the painting process and replay it with a higher result
## resolution.

const Brush = preload("brush.gd")
const CameraState = preload("camera_state.gd")

var camera_state : CameraState
var model_transform : Transform3D
var brush_transform : Transform3D
var screen_position : Vector2
var brush : Brush
var pressure : float

func _init(_camera_state, _model_transform, _screen_position : Vector2, _brush : Brush, _pressure : float, _brush_transform: Transform3D) -> void:
	camera_state = _camera_state
	model_transform = _model_transform
	brush_transform = _brush_transform
	screen_position = _screen_position
	brush = _brush
	pressure = _pressure
