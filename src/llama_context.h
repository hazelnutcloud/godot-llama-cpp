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
  llama_batch batch = llama_batch_init(512, 0, 1);
  int task_id;

protected:
	static void _bind_methods();

public:
	void set_model(const Ref<LlamaModel> model);
	Ref<LlamaModel> get_model();
  Variant request_completion(const String &prompt);
  void _fulfill_completion(const String &prompt);
	virtual void _ready() override;
  ~LlamaContext();
};
} //namespace godot

#endif