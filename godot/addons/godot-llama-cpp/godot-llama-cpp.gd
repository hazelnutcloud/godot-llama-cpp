@tool
extends EditorPlugin


func _enter_tree():
	# Initialization of the plugin goes here.
	add_autoload_singleton("__LlamaBackend", "res://addons/godot-llama-cpp/autoloads/llama-backend.gd")


func _exit_tree():
	# Clean-up of the plugin goes here.
	remove_autoload_singleton("__LlamaBackend")
