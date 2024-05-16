#ifndef LLAMA_CONTEXT_H
#define LLAMA_CONTEXT_H

#include "llama.h"
#include "common.h"
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
  llama_sampling_context *sampling_ctx = nullptr;
	llama_context_params ctx_params;
  llama_sampling_params sampling_params;
  int n_len = 1024;
	int request_id = 0;
	Vector<completion_request> completion_requests;

	Ref<Thread> thread;
	Ref<Semaphore> semaphore;
	Ref<Mutex> mutex;
  std::vector<llama_token> context_tokens;
  bool exit_thread = false;

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
  int get_n_len();
  void set_n_len(int n_len);
  float get_temperature();
  void set_temperature(float temperature);
  float get_top_p();
  void set_top_p(float top_p);
  float get_frequency_penalty();
  void set_frequency_penalty(float frequency_penalty);
  float get_presence_penalty();
  void set_presence_penalty(float presence_penalty);

	virtual PackedStringArray _get_configuration_warnings() const override;
	virtual void _ready() override;
  virtual void _exit_tree() override;
	LlamaContext();
};
} //namespace godot

#endif