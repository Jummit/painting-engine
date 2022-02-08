extends Reference

"""
Utility to store all members of a camera relevant to rendering.
"""

const MEMBERS := ["keep_aspect", "transform", "h_offset", "v_offset", "size",
		"fov", "near", "far", "projection"]

var _state : Dictionary

func _init(camera : Camera) -> void:
	for member in MEMBERS:
		_state[member] = camera[member]


# Replicate all stored members to the given camera.
func apply(camera : Camera) -> void:
	for member in MEMBERS:
		camera[member] = _state[member]

