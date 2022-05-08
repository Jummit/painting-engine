extends WATTest
# warning-ignore-all:function_may_yield

const MultiYielder = preload("res://addons/painter/utils/multi_yielder.gd")

func test_one_yield() -> void:
	describe("MultiYielder works when given one function to wait for")
	var yielder := MultiYielder.new()
	yielder.add(do_something(), "completed")
	await yielder.all_completed
	asserts.auto_pass("Yielded for multiple functions")


func test_multiple_yields() -> void:
	describe("MultiYielder works when given multiple functions to wait for")
	var yielder := MultiYielder.new()
	yielder.add(do_something(), "completed")
	yielder.add(do_something(), "completed")
	yielder.add(do_something(), "completed")
	await yielder.all_completed
	asserts.auto_pass("Yielded for multiple functions")


func do_something():
	await get_tree().create_timer(0.01 * randf()).timeout
