extends Node

const message = preload("res://examples/simple/message.tscn")

@onready var messages_container = %MessagesContainer
@onready var llama_context = %LlamaContext

func _on_text_edit_submit(input: String) -> void:
	handle_input(input)

func handle_input(input: String) -> void:
	var completion_id = llama_context.request_completion(input)
	
	var user_message: Message = message.instantiate()
	messages_container.add_child(user_message)
	user_message.set_text(input)
	user_message.sender = "user"
	user_message.completion_id = completion_id
	
	var ai_message: Message = message.instantiate()
	messages_container.add_child(ai_message)
	ai_message.sender = "assistant"
	ai_message.completion_id = completion_id
	ai_message.pending = true
	


func _on_llama_context_completion_generated(chunk: Dictionary) -> void:
	var completion_id = chunk.id
	for message: Message in messages_container.get_children():
		if message.completion_id != completion_id or message.sender != "assistant":
			continue
		if chunk.has("error"):
			message.errored = true
		elif chunk.has("text"):
			if message.pending:
				message.pending = false
				message.set_text(chunk["text"])
			else:
				message.append_text(chunk["text"])
