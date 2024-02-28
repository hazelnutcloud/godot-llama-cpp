#ifndef LLAMA_MODEL_H
#define LLAMA_MODEL_H

#include <llama.h>
#include <godot_cpp/classes/resource.hpp>

namespace godot {

	class LlamaModel : public Resource {
		GDCLASS(LlamaModel, Resource)

	protected:
		static void _bind_methods();

	public:
    llama_model *model = nullptr;
		void load_model( const String &path );
    ~LlamaModel();
	};

} //namespace godot

#endif