# This script will be autoloaded by the editor plugin
extends Node

var backend: LlamaBackend = LlamaBackend.new()

func _enter_tree() -> void:
  backend.init()

func _exit_tree() -> void:
  backend.deinit()
