class_name Message
extends Node

var ai_avatar = preload ("res://addons/godot-llama-cpp/assets/godot-llama-cpp-1024x1024.svg")
var user_avatar = preload ("res://examples/simple/user.svg")
var system_avatar = preload("res://examples/simple/system.svg")
var stylebox: StyleBoxTexture = StyleBoxTexture.new()

@onready var text_container = %Text
@onready var icon = %Panel
@export_enum("user", "assistant", "system") var sender: String:
	get:
		return sender
	set(value):
		sender = value
		if icon == null: return
		if value == "user":
			stylebox.texture = user_avatar
		elif value == "assistant":
			stylebox.texture = ai_avatar
		else:
			stylebox.texture = system_avatar
		icon.add_theme_stylebox_override("panel", stylebox)
@export var include_in_prompt: bool = true
@export var text: String:
	get:
		return text
	set(value):
		text = value
		if text_container == null: 
			return
		text_container.text = value

var completion_id: int = -1
var pending: bool = false
var errored: bool = false

func _ready():
	text_container.text = text
	sender = sender


