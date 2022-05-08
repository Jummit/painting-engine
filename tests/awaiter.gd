extends WATTest
# warning-ignore-all:function_may_yield

const Awaiter = preload("res://addons/painter/utils/awaiter.gd")

func test_awaiter() -> void:
	describe("Test the Awaiter with yielding functions")
	asserts.is_equal(await Awaiter.new(do_something()).done, 3, "Awaiting a function that yields works")
	asserts.is_equal(await Awaiter.new(do_something_with_more_yields()).done, 5, "Awaiting a function that yields multiple times works")


func test_await_value() -> void:
	describe("Test the Awaiter with a value")
	asserts.is_equal(await Awaiter.new(5).done, 5, "Awaiting a value works")


func do_something():
	await get_tree().create_timer(0.01).timeout
	return 3


func do_something_with_more_yields():
	await get_tree().create_timer(0.01).timeout
	await get_tree().create_timer(0.01).timeout
	await get_tree().create_timer(0.01).timeout
	return 5
