class_name ChatFormatter

static func apply(format: String, messages: Array) -> String:
	match format:
		"llama3":
			return format_llama3(messages)
		"phi3":
			return format_phi3(messages)
		"mistral":
			return format_mistral(messages)
		_:
			printerr("Unknown chat format: ", format)
			return ""

static func format_llama3(messages: Array) -> String:
	var res = ""
	
	for i in range(messages.size()):
		match messages[i]:
			{"text": var text, "sender": var sender}:
				res += """<|start_header_id|>%s<|end_header_id|>

%s<|eot_id|>
""" % [sender, text]
			_:
				printerr("Invalid message at index ", i)

	res += "<|start_header_id|>assistant<|end_header_id|>\n\n"
	return res

static func format_phi3(messages: Array) -> String:
	var res = ""
	
	for i in range(messages.size()):
		match messages[i]:
			{"text": var text, "sender": var sender}:
				res +="<|%s|>\n%s<|end|>\n" % [sender, text]
			_:
				printerr("Invalid message at index ", i)
	res += "<|assistant|>\n"
	return res
	
static func format_mistral(messages: Array) -> String:
	var res = ""
	
	for i in range(messages.size()):
		match messages[i]:
			{"text": var text, "sender": var sender}:
				if sender == "user":
					res += "[INST] %s [/INST]" % text
				else:
					res += "%s</s>"
			_:
				printerr("Invalid message at index ", i)
	
	return res
