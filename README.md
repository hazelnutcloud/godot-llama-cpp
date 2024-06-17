<div align='center'>

<img width="100" src="/godot/addons/godot-llama-cpp/assets/godot-llama-cpp-1024x1024.svg">

<h1>godot-llama-cpp</h1>

Run large language models in [Godot](https://godotengine.org). Powered by [llama.cpp](https://github.com/ggerganov/llama.cpp).

<br />
<br />

![Godot v4.2](https://img.shields.io/badge/Godot-v4.2-%23478cbf?logo=godot-engine&logoColor=white)
![GitHub last commit](https://img.shields.io/github/last-commit/hazelnutcloud/godot-llama-cpp)
![GitHub License](https://img.shields.io/github/license/hazelnutcloud/godot-llama-cpp)

</div>

## Overview

This library aims to provide a high-level interface to run large language models in Godot, following Godot's node-based design principles.

```gdscript
@onready var llama_context = %LlamaContext

var messages = [
  { "sender": "system", "text": "You are a pirate chatbot who always responds in pirate speak!" },
  { "sender": "user", "text": "Who are you?" }
]
var prompt = ChatFormatter.apply("llama3", messages)
var completion_id = llama_context.request_completion(prompt)

while (true):
  var response = await llama_context.completion_generated
  print(response["text"])

  if response["done"]: break
```

## Features
  
  - Chat formatter for:
    - [x] Llama3
    - [x] Mistral
    - [ ] More to come!
  - Compute backend builds:
    - [x] Metal
    - [ ] Vulkan
    - [ ] CUDA
  - Asynchronous completion generation
  - Support any language model that llama.cpp supports in GGUF format
  - GGUF files are Godot resources

## Building & Installation

1. Download zig v0.13.0 from https://ziglang.org/download/
2. Clone the repository:
   ```bash
   git clone --recurse-submodules https://github.com/hazelnutcloud/godot-llama-cpp.git
   ```
3. Copy the `godot-llama-cpp` addon folder in `godot/addons` to your Godot project's `addons` folder.
   ```bash
    cp -r godot-llama-cpp/godot/addons/godot-llama-cpp <your_project>/addons
   ```
4. Build the extension and install it in your Godot project:
   ```bash
   cd godot-llama-cpp
   zig build --prefix <your_project>/addons/godot-llama-cpp
   ```
5. Enable the plugin in your Godot project settings.
6. Add the `LlamaContext` node to your scene.
7. Run your Godot project.
8. Enjoy!

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE.md) file for details.
