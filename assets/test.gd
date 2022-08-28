@tool
extends EditorScript

func _run():
	var a = "a"
	match a:
		"a":
			print("1")
		_:
			print("other")
