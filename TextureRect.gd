extends TextureRect

func _on_line_edit_text_changed(new_text):
	print(get_tree().root.get_node(new_text))
	if get_tree().root.has_node(new_text) and get_tree().root.get_node(new_text) is Viewport:
		texture = get_tree().root.get_node(new_text).get_texture()
