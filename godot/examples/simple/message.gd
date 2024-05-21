class_name Message
extends Node

@onready var text_container = %Text
@onready var icon = %Panel
@export_enum("user", "assistant") var sender: String
@export var include_in_prompt: bool = true
var text:
	get:
		return text_container.text
	set(value):
		text_container.text = value

var completion_id: int = -1
var pending: bool = false
var errored: bool = false

func set_text(new_text: String):
	text_container.text = new_text
	
func append_text(new_text: String):
	text_container.text += new_text

