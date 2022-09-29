extends TextureRect

## TODO: remove this

func _on_line_edit_text_changed(new_text):
	if not owner.has_node(new_text):
		return
	var node = owner.get_node(new_text)
	if node is Viewport:
		texture = node.get_texture()
