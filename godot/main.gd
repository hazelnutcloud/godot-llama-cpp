extends Node

@onready var input: TextEdit = %Input
@onready var submit_button: Button = %SubmitButton
@onready var output: Label = %Output

func _on_button_pressed():
	handle_submit()
	
func handle_submit():
	print(Llama.prompt(input.text))
	#print(input.text)
	
	#input.clear()
	#input.editable = false
	#submit_button.disabled = true
	#output.text = "..."
	#
	var completion = await Llama.text_generated
	#output.text = ""
	while !completion[2]:
		print(completion)
		#output.text += completion[0]
		completion = await Llama.text_generated
		#
	#input.editable = true
	#submit_button.disabled = false
