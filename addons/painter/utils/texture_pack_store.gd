extends RefCounted

## Utility for saving and loading textures to memory or disk.
##
## [b]Example Usage:[/b]
## [codeblock]
## var store = TexturePackStore.new("user://textures")
## stare.max_packs_in_memory = 1
## var pack_a = store.add_textures([a, b, c])
## var pack_b = store.add_textures([d, e, f])
## var a_textures = pack_a.get_textures()
## store.cleanup()
## [/codeblock]

## The maximum Pack objects stored in ram. When this value is exceeded the
## oldest packs will be saved to disk.
var max_packs_in_memory := 10
## The maximum packs to save to disk before the oldest are deleted.
var max_packs_on_disk := 30

var _packs : Array
var _last_id := 0
var _save_threads : Dictionary
var _folder : String

class Pack extends RefCounted:
	var textures : Array
	var file_count : int
	var saved : Array[String]
	var save : Callable
	var id : int
	var thread : Thread
	
	func _init(_textures,_id):
		textures = _textures
		file_count = textures.size()
		id = _id
	
	func get_textures() -> Array:
		if textures.is_empty() and not saved.is_empty():
			# Move textures back to memory.
			for file in saved:
				textures.append(ImageTexture.create_from_image(Image.load_from_file(file)))
				print("Deleted and loaded '", file)
			erase_from_disk()
		return textures
	
	func save_to_disk() -> void:
		save.call(self)
	
	func erase_from_disk() -> void:
		if saved.is_empty():
			return
		for file in saved:
			DirAccess.remove_absolute(file)
		DirAccess.remove_absolute(saved.front().get_base_dir())
		saved.clear()
	
	func _notification(what):
		if what == NOTIFICATION_PREDELETE and not saved.is_empty():
			# Can't call functions here, see
			# https://github.com/godotengine/godot/issues/31166.
#			erase_from_disk()
			for file in saved:
				DirAccess.remove_absolute(file)
			saved.clear()
			DirAccess.remove_absolute(saved.front().get_base_dir)

func _init(path : String):
	_folder = path
	DirAccess.make_dir_recursive_absolute(path)


## Add a new list of textures and return a pack that can be used to load textures
## at a later point in time.
func add_textures(new_textures : Array) -> Pack:
	var textures := []
	for texture in new_textures:
		if texture is ViewportTexture:
			texture = ImageTexture.create_from_image(texture.get_image())
		textures.append(texture)
	var new_pack := Pack.new(textures, _last_id)
	new_pack.save = self._save_pack
	_packs.append(weakref(new_pack))
	_last_id += 1
	_save_to_disk_if_needed()
	var on_disk := _get_packs(false)
	if on_disk.size() > max_packs_on_disk:
		# TODO: remove this, maybe make verbose?
		print("too many saved")
		# Don't free it, just clear the disk and memory space.
		on_disk.front().get_ref().textures.clear()
		on_disk.front().get_ref().erase_from_disk()
		_packs.erase(on_disk.front())
	return new_pack


func clear() -> void:
	var path := ProjectSettings.globalize_path(_folder)
	var dir := DirAccess.open(path)
	if dir:
		dir.remove(".")
		if dir.dir_exists("."):
			OS.move_to_trash(path)


func _get_packs(in_memory : bool) -> Array:
	var packs := []
	for pack in _packs:
		if pack.get_ref():
			var pack_in_memory : bool = (pack.get_ref() as Pack).saved.is_empty()\
				and not pack.get_ref().id in _save_threads
			if in_memory == pack_in_memory:
				packs.append(pack)
	return packs


func _save_to_disk_if_needed() -> void:
	var packs_in_memory := _get_packs(true)
	if packs_in_memory.size() > max_packs_in_memory:
		packs_in_memory.front().get_ref().save_to_disk()


# Function called by a pack so threads can be handled here, to avoid packs with
# unfinished threads being freed.
func _save_pack(pack : Pack):
	var thread := Thread.new()
	_save_threads[pack.id] = thread
	thread.start(_threaded_save_to_disk.bind(pack))


func _threaded_save_to_disk(pack : Pack) -> void:
	var base := _folder.path_join(str(pack.id))
	DirAccess.make_dir_recursive_absolute(base)
	for texture_num in pack.textures.size():
		# TODO: remove this or make verbose
		var path := base.path_join(str(texture_num) + ".png")
		print("Saved to ", path)
		pack.textures[texture_num].get_image().save_png(path)
		pack.saved.append(path)
	pack.textures.clear()
	call_deferred("_save_thread_completed", pack.id)


func _save_thread_completed(pack_for : int):
	_save_threads[pack_for].wait_to_finish()
	_save_threads.erase(pack_for)
