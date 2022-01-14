extends WATTest
# warning-ignore-all:function_may_yield

const MultiYielder = preload("res://addons/painter/utils/multi_yielder.gd")

func test_one_yield() -> void:
	var yielder := MultiYielder.new()
	yielder.add(do_something(), "completed")
	yield(yielder, "all_completed")
	asserts.auto_pass("Yielded for multiple functions")


func test_multiple_yields() -> void:
	var yielder := MultiYielder.new()
	yielder.add(do_something(), "completed")
	yielder.add(do_something(), "completed")
	yielder.add(do_something(), "completed")
	yield(yielder, "all_completed")
	asserts.auto_pass("Yielded for multiple functions")


func do_something():
	yield(get_tree().create_timer(0.01 * randf()), "timeout")
