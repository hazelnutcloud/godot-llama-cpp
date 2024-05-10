extends TextEdit

signal submit(input: String)
	
func _gui_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var keycode = event.get_keycode_with_modifiers()
		if keycode == KEY_ENTER and event.is_pressed():
			handle_submit()
			accept_event()
		if keycode == KEY_ENTER | KEY_MASK_SHIFT and event.is_pressed():
			insert_text_at_caret("\n")
			accept_event()

func _on_button_pressed() -> void:
	handle_submit()

func handle_submit() -> void:
	submit.emit(text)
	text = ""
