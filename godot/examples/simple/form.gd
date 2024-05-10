extends HBoxContainer

@onready var text_edit = %TextEdit

func _on_button_pressed() -> void:
	text_edit.handle_submit()
