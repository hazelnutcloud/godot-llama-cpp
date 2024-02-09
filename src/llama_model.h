#ifndef LLAMA_MODEL_H
#define LLAMA_MODEL_H

#include "llama.h"
#include <godot_cpp/classes/resource.hpp>

namespace godot {

	class LlamaModel : public Resource {
		GDCLASS(LlamaModel, Resource)

	private:
		const char* resource_path;
		llama_model* model;

	protected:
		static void _bind_methods();

	public:
		LlamaModel();
		~LlamaModel();
	};

} //namespace godot

#endif