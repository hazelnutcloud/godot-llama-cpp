#ifndef LLAMA_CONTEXT_H
#define LLAMA_CONTEXT_H

#include "llama.h"
#include "llama_model.h"
#include <godot_cpp/classes/mutex.hpp>
#include <godot_cpp/classes/node.hpp>
#include <godot_cpp/classes/semaphore.hpp>
#include <godot_cpp/classes/thread.hpp>
#include <godot_cpp/templates/vector.hpp>
namespace godot {

struct completion_request {
	int id;
	String prompt;
};

class LlamaContext : public Node {
	GDCLASS(LlamaContext, Node)

private:
	Ref<LlamaModel> model;
	llama_context *ctx = nullptr;
	llama_context_params ctx_params;
	int request_id = 0;
	Vector<completion_request> completion_requests;

	Ref<Thread> thread;
	Ref<Semaphore> semaphore;
	Ref<Mutex> mutex;

protected:
	static void _bind_methods();

public:
	void set_model(const Ref<LlamaModel> model);
	Ref<LlamaModel> get_model();

	int request_completion(const String &prompt);
	void __thread_loop();

	int get_seed();
	void set_seed(int seed);
	int get_n_ctx();
	void set_n_ctx(int n_ctx);

	virtual PackedStringArray _get_configuration_warnings() const override;
	virtual void _ready() override;
	LlamaContext();
	~LlamaContext();
};
} //namespace godot

#endif