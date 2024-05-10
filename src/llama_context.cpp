#include "llama_context.h"
#include "common.h"
#include "llama.h"
#include "llama_model.h"
#include <godot_cpp/classes/engine.hpp>
#include <godot_cpp/classes/os.hpp>
#include <godot_cpp/classes/worker_thread_pool.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/utility_functions.hpp>
#include <godot_cpp/variant/dictionary.hpp>

using namespace godot;

void LlamaContext::_bind_methods() {
	ClassDB::bind_method(D_METHOD("set_model", "model"), &LlamaContext::set_model);
	ClassDB::bind_method(D_METHOD("get_model"), &LlamaContext::get_model);
	ClassDB::add_property("LlamaContext", PropertyInfo(Variant::OBJECT, "model", PROPERTY_HINT_RESOURCE_TYPE, "LlamaModel"), "set_model", "get_model");

	ClassDB::bind_method(D_METHOD("get_seed"), &LlamaContext::get_seed);
	ClassDB::bind_method(D_METHOD("set_seed", "seed"), &LlamaContext::set_seed);
	ClassDB::add_property("LlamaContext", PropertyInfo(Variant::INT, "seed"), "set_seed", "get_seed");

	ClassDB::bind_method(D_METHOD("get_n_ctx"), &LlamaContext::get_n_ctx);
	ClassDB::bind_method(D_METHOD("set_n_ctx", "n_ctx"), &LlamaContext::set_n_ctx);
	ClassDB::add_property("LlamaContext", PropertyInfo(Variant::INT, "n_ctx"), "set_n_ctx", "get_n_ctx");

	ClassDB::bind_method(D_METHOD("request_completion", "prompt"), &LlamaContext::request_completion);
	ClassDB::bind_method(D_METHOD("__thread_loop"), &LlamaContext::__thread_loop);

	ADD_SIGNAL(MethodInfo("completion_generated", PropertyInfo(Variant::DICTIONARY, "chunk")));
}

LlamaContext::LlamaContext() {
	ctx_params = llama_context_default_params();
	ctx_params.seed = -1;
	ctx_params.n_ctx = 4096;

	int32_t n_threads = OS::get_singleton()->get_processor_count();
	ctx_params.n_threads = n_threads;
	ctx_params.n_threads_batch = n_threads;
}

void LlamaContext::_ready() {
	// TODO: remove this and use runtime classes once godot 4.3 lands, see https://github.com/godotengine/godot/pull/82554
	if (Engine::get_singleton()->is_editor_hint()) {
		return;
	}

	if (model->model == NULL) {
		UtilityFunctions::printerr(vformat("%s: Failed to initialize llama context, model property not defined", __func__));
		return;
	}

	mutex.instantiate();
	semaphore.instantiate();
	thread.instantiate();

	llama_backend_init();
	llama_numa_init(ggml_numa_strategy::GGML_NUMA_STRATEGY_DISABLED);

	ctx = llama_new_context_with_model(model->model, ctx_params);
	if (ctx == NULL) {
		UtilityFunctions::printerr(vformat("%s: Failed to initialize llama context, null ctx", __func__));
		return;
	}
	UtilityFunctions::print(vformat("%s: Context initialized", __func__));

	thread->start(callable_mp(this, &LlamaContext::__thread_loop));
}

void LlamaContext::__thread_loop() {
	while (true) {
		semaphore->wait();

		mutex->lock();
		if (completion_requests.size() == 0) {
			mutex->unlock();
			continue;
		}
		completion_request req = completion_requests.get(0);
		completion_requests.remove_at(0);
		mutex->unlock();

		UtilityFunctions::print(vformat("%s: Running completion for prompt id: %d", __func__, req.id));

    Dictionary chunk;
    chunk["id"] = req.id;
    chunk["text"] = "Hello, world!";
    call_deferred("emit_signal", "completion_generated", chunk);
	}
}

PackedStringArray LlamaContext::_get_configuration_warnings() const {
	PackedStringArray warnings;
	if (model == NULL) {
		warnings.push_back("Model resource property not defined");
	}
	return warnings;
}

int LlamaContext::request_completion(const String &prompt) {
	int id = request_id++;

	UtilityFunctions::print(vformat("%s: Requesting completion for prompt id: %d", __func__, id));

	mutex->lock();
	completion_request req = { id, prompt };
	completion_requests.append(req);
	mutex->unlock();

	semaphore->post();

	return id;
}

void LlamaContext::set_model(const Ref<LlamaModel> p_model) {
	model = p_model;
}
Ref<LlamaModel> LlamaContext::get_model() {
	return model;
}

int LlamaContext::get_seed() {
	return ctx_params.seed;
}
void LlamaContext::set_seed(int seed) {
	ctx_params.seed = seed;
}

int LlamaContext::get_n_ctx() {
	return ctx_params.n_ctx;
}
void LlamaContext::set_n_ctx(int n_ctx) {
	ctx_params.n_ctx = n_ctx;
}

LlamaContext::~LlamaContext() {
	if (ctx) {
		llama_free(ctx);
	}

	llama_backend_free();
}