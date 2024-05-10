extends Node

@onready var messages_container = %MessagesContainer
@onready var llama_context = %LlamaContext

var message = preload("res://examples/simple/message.tscn")

func _on_text_edit_submit(input: String) -> void:
	handle_input(input)

func handle_input(input: String) -> void:
	var new_message = message.instantiate()
	new_message.text = input
	messages_container.add_child(new_message)
	
	var id = llama_context.request_completion(input)
	print("request id: ", id)
	


func _on_llama_context_completion_generated(chunk: Dictionary) -> void:
	print("new chunk: ", chunk)
