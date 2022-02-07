extends Reference

const MEMBERS := ["keep_aspect", "transform", "h_offset", "v_offset", "size",
		"fov", "near", "far", "projection"]

var state : Dictionary

func _init(camera : Camera) -> void:
	for member in MEMBERS:
		state[member] = camera[member]


func apply(camera : Camera) -> void:
	for member in MEMBERS:
		camera[member] = state[member]
