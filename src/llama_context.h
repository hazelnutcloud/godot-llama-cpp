#ifndef LLAMA_CONTEXT_H
#define LLAMA_CONTEXT_H

#include "llama.h"
#include "llama_model.h"
#include <godot_cpp/classes/node.hpp>

namespace godot {
class LlamaContext : public Node {
	GDCLASS(LlamaContext, Node)

private:
	Ref<LlamaModel> model;
	llama_context *ctx = nullptr;
  llama_context_params ctx_params = llama_context_default_params();

protected:
	static void _bind_methods();

public:
	void set_model(const Ref<LlamaModel> model);
	Ref<LlamaModel> get_model();
	virtual void _ready() override;
  ~LlamaContext();
};
} //namespace godot

#endif