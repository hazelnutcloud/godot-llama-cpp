extends Node

@onready var input: TextEdit = %Input
@onready var submit_button: Button = %SubmitButton
@onready var output: Label = %Output

func _on_button_pressed():
	handle_submit()
	
#func _unhandled_key_input(event: InputEvent) -> void:
	#if (event.is_action_released("submit_form") and input.has_focus()):
		#handle_submit()
	
func handle_submit():
	print(input.text)
	Llama.request_completion(input.text)
	
	input.clear()
	input.editable = false
	submit_button.disabled = true
	output.text = "..."
	
	var completion = await Llama.completion_generated
	output.text = ""
	while !completion[1]:
		print(completion[0])
		output.text += completion[0]
		completion = await Llama.completion_generated
		
	input.editable = true
	submit_button.disabled = false
