extends WATTest

const Brush = preload("res://addons/painter/brush.gd")

func test_duplicate() -> void:
	describe("A duplicated brush doesn't affect the original")

	var a := Brush.new()
	a.size = 1
	var b : Brush = a.duplicate()
	b.size = 2
	asserts.is_equal(a.size, 1, "Size of duplicated brush stays the same.")
	asserts.is_equal(b.size, 2, "Size of original brush changed.")

