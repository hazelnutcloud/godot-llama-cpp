extends Node

const message = preload("res://examples/simple/message.tscn")

@onready var messages_container = %MessagesContainer
@onready var llama_context = %LlamaContext

func _on_text_edit_submit(input: String) -> void:
	handle_input(input)

func handle_input(input: String) -> void:
	var messages = [{ "sender": "system", "text": "You are a helpful assistant" }]
	messages.append_array(messages_container.get_children().filter(func(msg: Message): return msg.include_in_prompt).map(
		func(msg: Message) -> Dictionary:
			return { "text": msg.text, "sender": msg.sender }
	))
	messages.append({"text": input, "sender": "user"})
	var prompt = ChatFormatter.apply("phi3", messages)
	print("prompt: ", prompt)
	
	var completion_id = llama_context.request_completion(prompt)
	
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
	ai_message.grab_focus()
	


func _on_llama_context_completion_generated(chunk: Dictionary) -> void:
	var completion_id = chunk.id
	for msg: Message in messages_container.get_children():
		if msg.completion_id != completion_id or msg.sender != "assistant":
			continue
		if chunk.has("error"):
			msg.errored = true
		elif chunk.has("text"):
			if msg.pending:
				msg.pending = false
				msg.set_text(chunk["text"])
			else:
				msg.append_text(chunk["text"])
