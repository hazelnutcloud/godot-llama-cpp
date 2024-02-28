#ifndef LLAMA_CONTEXT_H
#define LLAMA_CONTEXT_H

#include <godot_cpp/classes/node.hpp>
#include "llama_model.h"

namespace godot {
	class LlamaContext : public Node {
		GDCLASS(LlamaContext, Node)

	private:
		Ref<LlamaModel> model;

	protected:
		static void _bind_methods(){};
	};
}

#endif