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
	llama_context_params ctx_params;
	llama_batch batch;
	int task_id;

protected:
	static void _bind_methods();

public:
	void set_model(const Ref<LlamaModel> model);
	Ref<LlamaModel> get_model();

	Variant request_completion(const String &prompt);
	void _fulfill_completion(const String &prompt);

  int get_seed();
  void set_seed(int seed);
  int get_n_ctx();
  void set_n_ctx(int n_ctx);
  int get_n_threads();
  void set_n_threads(int n_threads);
  int get_n_threads_batch();
  void set_n_threads_batch(int n_threads_batch);

  virtual PackedStringArray _get_configuration_warnings() const override;
	virtual void _ready() override;
  LlamaContext();
	~LlamaContext();
};
} //namespace godot

#endif