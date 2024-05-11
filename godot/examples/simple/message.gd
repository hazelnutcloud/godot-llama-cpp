class_name Message
extends Node

@onready var text_container = %Text
@onready var icon = %Panel
@export_enum("user", "assistant") var sender: String

var completion_id: int = -1
var pending: bool = false
var errored: bool = false

func set_text(new_text: String):
	text_container.text = new_text
	
func append_text(new_text: String):
	text_container.text += new_text

