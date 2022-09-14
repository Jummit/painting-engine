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
var _path : String

class Pack extends RefCounted:
	var textures : Array
	var file_count : int
	var file_on_disk : String
	var save : Callable
	var id : int
	var thread : Thread
	
	func _init(_textures,_id):
		textures = _textures
		file_count = textures.size()
		id = _id
	
	func get_textures() -> Array:
		if textures.is_empty() and not file_on_disk.is_empty():
			# Move textures back to memory.
			var dir := Directory.new()
			dir.open("user://")
			for file_num in file_count:
				var image := Image.new()
				image.load(file_on_disk % file_num)
				var texture := ImageTexture.new()
				texture.create_from_image(image)
				dir.remove(file_on_disk % file_num)
				textures.append(texture)
		return textures
	
	func save_to_disk() -> void:
		save.call(self)
	
	func erase_from_disk() -> void:
		if file_on_disk.is_empty():
			return
		var dir := Directory.new()
		for texture_num in file_count:
			dir.remove(file_on_disk % texture_num)
	
	func get_path_on_disk(texture : int) -> String:
		if file_on_disk.is_empty():
			return ""
		return file_on_disk % str(texture - 1)
	
	func _notification(what):
		if what == NOTIFICATION_PREDELETE and file_on_disk:
			# Can't call functions here, see
			# https://github.com/godotengine/godot/issues/31166.
#			erase_from_disk()
			var dir := Directory.new()
			for texture_num in file_count:
				dir.remove(file_on_disk % texture_num)

func _init(path : String):
	_path = path.path_join("/%s_%s.png")
	var dir := Directory.new()
	dir.open("")
	dir.remove(path)
	dir.make_dir_recursive(path)


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
		on_disk.front().get_ref().file_on_disk = ""
		_packs.erase(on_disk.front())
	return new_pack


func cleanup() -> void:
	# Because remove_at doesn't delete recursively, delete the packs one-by one.
	var dir := Directory.new()
	for pack in _packs:
		if pack.get_ref():
			pack.get_ref().erase_from_disk()
	dir.open("")
	# TODO: remove this, maybe make verbose?
	print("clean ", _path.get_base_dir())
	dir.remove(_path.get_base_dir())


func _get_packs(in_memory : bool) -> Array:
	var packs := []
	for pack in _packs:
		if pack.get_ref():
			var pack_in_memory : bool = (pack.get_ref() as Pack).file_on_disk.is_empty()\
				and not pack.get_ref().id in _save_threads
			if in_memory == pack_in_memory:
				packs.append(pack)
	return packs


func _save_to_disk_if_needed() -> void:
	var packs_in_memory := _get_packs(true)
	if packs_in_memory.size() > max_packs_in_memory:
		print("save to disk")
		packs_in_memory.front().get_ref().save_to_disk()


# Function called by a pack so threads can be handled here, to avoid packs with
# unfinished threads being freed.
func _save_pack(pack : Pack):
	var thread := Thread.new()
	_save_threads[pack.id] = thread
	thread.start(_threaded_save_to_disk.bind(pack))


func _threaded_save_to_disk(pack : Pack) -> void:
	var path := _path % [pack.id, "%s"]
	for texture_num in pack.textures.size():
		# TODO: remove this or make verbose
		print(pack.textures[texture_num], path % texture_num)
		pack.textures[texture_num].get_image().save_png(path % texture_num)
	pack.textures.clear()
	pack.file_on_disk = path
	call_deferred("_save_thread_completed", pack.id)


func _save_thread_completed(pack_for : int):
	_save_threads[pack_for].wait_to_finish()
	_save_threads.erase(pack_for)
