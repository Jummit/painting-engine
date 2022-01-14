extends Reference

"""
Utility class that can yield for multiple signals
"""

signal all_completed

var yields_left : int

func add(object : Object, signal_name : String):
	yields_left += 1
	yield(object, signal_name)
	yields_left -= 1
	if not yields_left:
		emit_signal("all_completed")
