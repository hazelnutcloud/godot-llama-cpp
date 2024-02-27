#ifndef LLAMA_MODEL_H
#define LLAMA_MODEL_H

#include <llama.h>
#include <godot_cpp/classes/resource.hpp>

namespace godot {

	class LlamaModel : public Resource {
		GDCLASS(LlamaModel, Resource)

  private:
    llama_model *model = nullptr;

	protected:
		static void _bind_methods();

	public:
		void load_model( const String &path );
    ~LlamaModel();
	};

} //namespace godot

#endif