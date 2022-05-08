extends WATTest

var red : Texture2D = load("res://tests/red.png")
var store : TexturePackStore

const FOLDER = "/tmp/painter_test_textures"
const TexturePackStore = preload("res://addons/painter/utils/texture_pack_store.gd")
const FileUtils = preload("res://addons/file_utils/file_utils.gd")

func pre() -> void:
	store = TexturePackStore.new(FOLDER)
	await until_timeout(0.01).YIELD


func post() -> void:
	store.cleanup()
	await until_timeout(0.01).YIELD
	FileUtils.remove_recursive(FOLDER)
	await until_timeout(0.01).YIELD


func test_in_memory() -> void:
	describe("Retrieving a pack from memory")
	var pack := store.add_textures([red])
	asserts.is_equal(pack.get_textures(), [red], "Pack can be retrieved")


func test_multiple_packs_in_memory() -> void:
	describe("Retrieving multiple packs from memory")
	store.add_textures([red])
	var pack := store.add_textures([red])
	asserts.is_equal(pack.get_textures(), [red], "Pack can be retrieved")


func test_multiple_textures_in_memory() -> void:
	describe("Retrieving multiple textures from memory")
	var pack := store.add_textures([red, red])
	asserts.is_equal(pack.get_textures(), [red, red], "Pack has multiple textures")


func test_folder_is_created() -> void:
	describe("Texture2D folder is created")
	asserts.folder_exists(FOLDER, "Created texture folder")


func test_folder_is_removed_on_cleanup() -> void:
	describe("Texture2D folder gets deleted on cleanup")
	store.max_packs_in_memory = 1
	store.add_textures([red])
	store.add_textures([red])
	await until_timeout(0.01).YIELD
	store.cleanup()
	await until_timeout(0.01).YIELD
	asserts.folder_does_not_exist(FOLDER, "Texture2D folder was deleted")


func test_save_to_disk() -> void:
	describe("Textures are save to disk when max packs in memory is exceeded")
	store.max_packs_in_memory = 1
	var pack := store.add_textures([red])
	store.add_textures([red])
	await until_timeout(0.01).YIELD
	asserts.file_exists(pack.get_path_on_disk(1), "Pack is saved to disk")


func test_deletion_after_retrieval() -> void:
	describe("Files are deleted after being retrieved")
	store.max_packs_in_memory = 1
	var a := store.add_textures([red])
	var path := a.get_path_on_disk(1)
	store.add_textures([red])
	await until_timeout(0.01).YIELD
	a.get_textures()
	asserts.file_does_not_exist(path, "Pack is deleted after being loaded")
