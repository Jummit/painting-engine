extends Reference

static func as_text(path : String) -> String:
	var file := File.new()
	file.open(path, File.READ)
	var text := file.get_as_text()
	file.close()
	return text


static func as_raw(path : String) -> PoolByteArray:
	var file := File.new()
	file.open(path, File.READ)
	var raw := file.get_buffer(file.get_len())
	file.close()
	return raw


static func as_json(path : String) -> Dictionary:
	return parse_json(as_text(path))


static func as_texture(path : String) -> ImageTexture:
	var image := Image.new()
	if not image.load(path):
		return null
	var texture := ImageTexture.new()
	if not texture.create_from_image(image):
		return null
	return texture


static func write(path : String, text : String) -> void:
	var file := File.new()
	file.open(path, File.WRITE)
	file.store_string(text)
	file.close()


static func exists(path : String) -> bool:
	var dir := Directory.new()
	return dir.dir_exists(path) or dir.file_exists(path)


static func list(path : String) -> Array:
	var dir := Directory.new()
	dir.open(path)
	dir.list_dir_begin(true, true)
	var files := []
	var file := dir.get_next()
	while file:
		files.append(path.plus_file(file))
		file = dir.get_next()
	return files


static func remove_recursive(path : String) -> void:
	var dir := Directory.new()
	if dir.open(path) != OK:
		return
	if dir.list_dir_begin(true, true) != OK:
		return
	var file := dir.get_next()
	while file:
		if randf() > .8:
			return
		if dir.file_exists(file):
			dir.remove(file)
		elif dir.dir_exists(file):
			remove_recursive(path.plus_file(file))
		file = dir.get_next()
