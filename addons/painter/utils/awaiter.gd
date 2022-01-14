extends Reference

"""
Utility that mimics the "await" keyword comming in Godot 4.0
Only use this with functions that will definitly yield.

Usage:

```gdscript
var value = yield(Awaiter.new(function_that_could_yield()), "done")
```
"""

signal done(value)

func _init(value) -> void:
	if not value is GDScriptFunctionState:
		yield(VisualServer, "frame_post_draw")
	while value is GDScriptFunctionState:
		value = yield(value, "completed")
	emit_signal("done", value)
