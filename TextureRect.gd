extends TextureRect

func _on_line_edit_text_changed(new_text):
	if not owner.has_node(new_text):
		return
	var node = owner.get_node(new_text)
	if node is Viewport:
		print("true")
		texture = node.get_texture()
