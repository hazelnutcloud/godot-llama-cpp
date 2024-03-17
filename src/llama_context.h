#ifndef LLAMA_CONTEXT_H
#define LLAMA_CONTEXT_H

#include "common.h"
#include "llama.h"
#include "llama_model.h"
#include <godot_cpp/classes/mutex.hpp>
#include <godot_cpp/classes/node.hpp>
#include <godot_cpp/classes/semaphore.hpp>
#include <godot_cpp/classes/thread.hpp>
#include <godot_cpp/templates/vector.hpp>

namespace godot {

struct prompt_request {
	int id;
	String prompt;
	int max_new_tokens;
	float temperature;
	float top_p;
	int top_k;
	float presence_penalty;
	float frequency_penalty;
};

class LlamaContext : public Node {
	GDCLASS(LlamaContext, Node)

private:
	Ref<LlamaModel> model;
	llama_context_params ctx_params;
	llama_context *ctx = nullptr;
	llama_sampling_params sampling_params;
	llama_sampling_context *sampling_ctx = nullptr;
	llama_batch batch;

	Ref<Thread> prompt_thread;
	Ref<Mutex> prompt_mutex;
	Ref<Semaphore> prompt_semaphore;
	bool should_exit;

	Vector<prompt_request> prompt_requests;
	int n_prompts;

protected:
	static void _bind_methods();

public:
	void set_model(const Ref<LlamaModel> model);
	Ref<LlamaModel> get_model();

	int prompt(const String &prompt, const int max_new_tokens, const float temperature, const float top_p, const int top_k, const float presence_penalty, const float frequency_penalty);
	void _thread_prompt_loop();

	int get_seed();
	void set_seed(const int seed);
	int get_n_ctx();
	void set_n_ctx(const int n_ctx);

	virtual PackedStringArray _get_configuration_warnings() const override;
	virtual void _ready() override;
	virtual void _exit_tree() override;
	LlamaContext();
	~LlamaContext();
};
} //namespace godot

#endif