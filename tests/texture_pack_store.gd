extends WATTest

var red : Texture = load("res://tests/red.png")

const FOLDER = "/tmp/painter_test_textures"
const TexturePackStore = preload("res://addons/painter/utils/texture_pack_store.gd")

class ReferenceHolder extends Object:
	var ref
	func _init(_ref):
		ref = _ref

func test_in_memory() -> void:
	describe("Retrieving textures from memory")
	
	var store := TexturePackStore.new(FOLDER)
	asserts.folder_exists(FOLDER, "Created texture folder")
	store.add_textures([red])
	var a := store.add_textures([red])
	var b := store.add_textures([red])
	var c := store.add_textures([red])
	yield(until_timeout(0.01), YIELD)
	
	asserts.is_equal(a.get_textures(), [red], "First pack can be retrieved")
	asserts.is_equal(c.get_textures(), [red], "Third pack can be retrieved")
	asserts.is_equal(b.get_textures(), [red], "Second pack can be retrieved")
	store.cleanup()
	asserts.folder_does_not_exist(FOLDER, "Folder deleted after cleanup")
	yield(get_tree(), "idle_frame")


func test_save_to_disk() -> void:
	describe("Of five textures three are save to disk")
	
	var store := TexturePackStore.new(FOLDER)
	store.max_packs_in_memory = 2
	var first := store.add_textures([red])
	var second := store.add_textures([red, red])
	var third := store.add_textures([red, red])
	var fourth := store.add_textures([red, red])
	var fifth := store.add_textures([red])
	yield(until_timeout(0.01), YIELD)
	
	asserts.folder_exists(FOLDER, "Created texture folder")
	asserts.file_exists(first.get_path_on_disk(1), "First pack is saved to disk")
	asserts.file_does_not_exist(first.get_path_on_disk(2), "First pack doesn't have two textures")
	asserts.file_exists(second.get_path_on_disk(1), "Second pack is saved to disk")
	asserts.file_exists(second.get_path_on_disk(2), "Second pack is saved to disk")
	asserts.file_exists(third.get_path_on_disk(1), "Third pack is saved to disk")
	asserts.file_exists(third.get_path_on_disk(2), "Third pack is saved to disk")
	asserts.file_does_not_exist(fourth.get_path_on_disk(1), "Fourth pack is not saved to disk")
	asserts.file_does_not_exist(fourth.get_path_on_disk(2), "Fourth pack is not saved to disk")
	asserts.file_does_not_exist(fifth.get_path_on_disk(1), "Fifth pack is not saved to disk")
	asserts.file_does_not_exist(fifth.get_path_on_disk(2), "Fifth pack is not saved to disk")
	store.cleanup()
	asserts.folder_does_not_exist(FOLDER, "Folder deleted after cleanup")


func test_deletion_after_free() -> void:
	describe("Files are deleted after the pack is freed")
	
	var store := TexturePackStore.new(FOLDER)
	store.max_packs_in_memory = 2
	var a := ReferenceHolder.new(store.add_textures([red, red]))
	var _b := ReferenceHolder.new(store.add_textures([red, red]))
	var _c := store.add_textures([red, red])
	var _d := store.add_textures([red])
	var _path_a_a : String = a.ref.get_path_on_disk(1)
	var _path_a_b : String = a.ref.get_path_on_disk(2)
	var path_b_a : String = a.ref.get_path_on_disk(1)
	var path_b_b : String = a.ref.get_path_on_disk(2)
	yield(until_timeout(0.01), YIELD)
	a.free()
	
	asserts.file_does_not_exist(path_b_a, "First pack is deleted after being freed")
	asserts.file_does_not_exist(path_b_b, "First pack is deleted after being freed")
	store.cleanup()
	asserts.folder_does_not_exist(FOLDER, "Folder deleted after cleanup")


func test_deletion_after_retrieval() -> void:
	describe("Files are deleted after being retrieved")
	
	var store := TexturePackStore.new(FOLDER)
	store.max_packs_in_memory = 2
	var a := ReferenceHolder.new(store.add_textures([red, red]))
	var _b := ReferenceHolder.new(store.add_textures([red, red]))
	store.add_textures([red, red])
	store.add_textures([red])
	yield(until_timeout(0.01), YIELD)
	var path_a_a : String = a.ref.get_path_on_disk(1)
	var path_a_b : String = a.ref.get_path_on_disk(2)
	
	asserts.file_exists(path_a_a, "Pack is saved to disk")
	asserts.file_exists(path_a_b, "Pack is saved to disk")
	var textures : Array = a.ref.get_textures()
	asserts.is_Object(textures[0], "First texture can be retrieved")
	asserts.is_Object(textures[1], "Second texture can be retrieved")
	asserts.file_does_not_exist(path_a_a, "Pack is deleted after being loaded")
	asserts.file_does_not_exist(path_a_b, "Pack is deleted after being loaded")
	store.cleanup()
	asserts.folder_does_not_exist(FOLDER, "Folder deleted after cleanup")
