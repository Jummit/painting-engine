extends Reference

"""
Utility for saving and loading textures to memory or disk.
"""

var max_packs_in_memory := 10
var max_packs_on_disk := 30

var _packs : Array
var _last_id := 0
var _save_threads : Dictionary
var _path : String

class Pack extends Reference:
	var textures : Array
	var file_count : int
	var file_on_disk : String
	var save_func : FuncRef
	var id : int
	var thread : Thread
	
	func _init(_textures, _id):
		textures = _textures
		file_count = textures.size()
		id = _id
	
	func get_textures() -> Array:
		if not textures and file_on_disk:
			# Move textures back to memory.
			var dir := Directory.new()
			for file_num in file_count:
				var image := Image.new()
				image.load(file_on_disk % file_num)
				var texture := ImageTexture.new()
				texture.create_from_image(image)
				dir.remove(file_on_disk % file_num)
				textures.append(texture)
		return textures
	
	func save_to_disk() -> void:
		save_func.call_func(self)
	
	func erase_from_disk() -> void:
		if not file_on_disk:
			return
		var dir := Directory.new()
		for texture_num in file_count:
			dir.remove(file_on_disk % texture_num)
	
	func get_path_on_disk(texture : int) -> String:
		if not file_on_disk:
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
	_path = path.plus_file("/%s_%s.png")
	var dir := Directory.new()
	dir.remove(path)
	dir.make_dir_recursive(path)


func add_textures(new_textures : Array) -> Pack:
	var textures := []
	for texture in new_textures:
		if texture is ViewportTexture:
			var image_texture := ImageTexture.new()
			image_texture.create_from_image(texture.get_data())
			texture = image_texture
		textures.append(texture)
	var new_pack := Pack.new(textures, _last_id)
	new_pack.save_func = funcref(self, "_save_pack")
	_packs.append(weakref(new_pack))
	_last_id += 1
	_save_to_disk_if_needed()
	var on_disk := _get_packs(false)
	if on_disk.size() > max_packs_on_disk:
		# Don't free it, just clear the disk and memory space.
		on_disk.front().get_ref().textures.clear()
		on_disk.front().get_ref().erase_from_disk()
		on_disk.front().get_ref().file_on_disk = ""
		_packs.erase(on_disk.front())
	return new_pack


func _get_packs(in_memory : bool) -> Array:
	var packs := []
	for pack in _packs:
		if pack.get_ref():
			var pack_in_memory : bool = not (pack.get_ref() as Pack).file_on_disk\
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
	thread.start(self, "_threaded_save_to_disk", pack)


func _threaded_save_to_disk(pack : Pack) -> void:
	var path := _path % [pack.id, "%s"]
	for texture_num in pack.textures.size():
		(pack.textures[texture_num] as Texture).get_data().save_png(
				path % texture_num)
	pack.textures.clear()
	pack.file_on_disk = path
	call_deferred("_save_thread_completed", pack.id)


func _save_thread_completed(pack_for : int):
	_save_threads[pack_for].wait_to_finish()
	_save_threads.erase(pack_for)


func cleanup() -> void:
	# Because remove doesn't delete recursively, delete the packs one-by one.
	var dir := Directory.new()
	for pack in _packs:
		if pack.get_ref():
			pack.get_ref().erase_from_disk()
	dir.remove(_path.get_base_dir())
