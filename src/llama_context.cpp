#include "llama_context.h"
#include "common.h"
#include "llama.h"
#include "llama_model.h"
#include <godot_cpp/classes/engine.hpp>
#include <godot_cpp/classes/os.hpp>
#include <godot_cpp/classes/worker_thread_pool.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/string.hpp>
#include <godot_cpp/variant/utility_functions.hpp>

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

	ClassDB::bind_method(D_METHOD("prompt", "prompt", "max_new_tokens", "temperature", "top_p", "top_k", "presence_penalty", "frequency_penalty"), &LlamaContext::prompt, DEFVAL(32), DEFVAL(0.80f), DEFVAL(0.95f), DEFVAL(40), DEFVAL(0.0), DEFVAL(0.0));
	ClassDB::bind_method(D_METHOD("_thread_prompt_loop"), &LlamaContext::_thread_prompt_loop);

	ADD_SIGNAL(MethodInfo("text_generated", PropertyInfo(Variant::INT, "id"), PropertyInfo(Variant::STRING, "text"), PropertyInfo(Variant::BOOL, "is_final")));
}

LlamaContext::LlamaContext() {
	batch = llama_batch_init(4096, 0, 1);

	ctx_params = llama_context_default_params();
	ctx_params.seed = -1;
	ctx_params.n_ctx = 4096;

	int32_t n_threads = OS::get_singleton()->get_processor_count();
	ctx_params.n_threads = n_threads;
	ctx_params.n_threads_batch = n_threads;

	sampling_params = llama_sampling_params();

	n_prompts = 0;
	should_exit = false;
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

	ctx = llama_new_context_with_model(model->model, ctx_params);
	if (ctx == NULL) {
		UtilityFunctions::printerr(vformat("%s: Failed to initialize llama context, null ctx", __func__));
		return;
	}
	UtilityFunctions::print(vformat("%s: Context initialized", __func__));

	sampling_ctx = llama_sampling_init(sampling_params);

	prompt_mutex.instantiate();
	prompt_semaphore.instantiate();
	prompt_thread.instantiate();

	prompt_thread->start(callable_mp(this, &LlamaContext::_thread_prompt_loop));
}

int LlamaContext::prompt(const String &prompt, const int max_new_tokens, const float temperature, const float top_p, const int top_k, const float presence_penalty, const float frequency_penalty) {
	UtilityFunctions::print(vformat("%s: Prompting with prompt: %s, max_new_tokens: %d, temperature: %f, top_p: %f, top_k: %d, presence_penalty: %f, frequency_penalty: %f", __func__, prompt, max_new_tokens, temperature, top_p, top_k, presence_penalty, frequency_penalty));
	prompt_mutex->lock();
	int id = n_prompts++;
	prompt_requests.push_back({ id, prompt, max_new_tokens, temperature, top_p, top_k, presence_penalty, frequency_penalty });
	prompt_mutex->unlock();
	prompt_semaphore->post();
	return id;
}

void LlamaContext::_thread_prompt_loop() {
	while (true) {
		prompt_semaphore->wait();

		prompt_mutex->lock();
		if (should_exit) {
			prompt_mutex->unlock();
			return;
		}
		if (prompt_requests.size() == 0) {
			prompt_mutex->unlock();
			continue;
		}
		prompt_request req = prompt_requests.get(0);
		prompt_requests.remove_at(0);
		prompt_mutex->unlock();

		UtilityFunctions::print(vformat("%s: Running prompt %d: %s, max_new_tokens: %d, temperature: %f, top_p: %f, top_k: %d, presence_penalty: %f, frequency_penalty: %f", __func__, req.id, req.prompt, req.max_new_tokens, req.temperature, req.top_p, req.top_k, req.presence_penalty, req.frequency_penalty));

		llama_sampling_reset(sampling_ctx);
		llama_batch_clear(batch);
		llama_kv_cache_clear(ctx);

		auto &params = sampling_ctx->params;
		params.temp = req.temperature;
		params.top_p = req.top_p;
		params.top_k = req.top_k;
		params.penalty_present = req.presence_penalty;
		params.penalty_freq = req.frequency_penalty;

		std::vector<llama_token> tokens = ::llama_tokenize(ctx, req.prompt.utf8().get_data(), false, true);
	}
}

PackedStringArray LlamaContext::_get_configuration_warnings() const {
	PackedStringArray warnings;
	if (model == NULL) {
		warnings.push_back("Model resource property not defined");
	}
	return warnings;
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
void LlamaContext::set_seed(const int seed) {
	ctx_params.seed = seed;
}

int LlamaContext::get_n_ctx() {
	return ctx_params.n_ctx;
}
void LlamaContext::set_n_ctx(const int n_ctx) {
	ctx_params.n_ctx = n_ctx;
}

void LlamaContext::_exit_tree() {
	prompt_mutex->lock();
	should_exit = true;
	prompt_requests.clear();
	prompt_mutex->unlock();

	prompt_semaphore->post();

	if (prompt_thread.is_valid()) {
		prompt_thread->wait_to_finish();
	}
	prompt_thread.unref();

	if (ctx) {
		llama_free(ctx);
	}
	if (sampling_ctx) {
		llama_sampling_free(sampling_ctx);
	}
}

LlamaContext::~LlamaContext() {
	llama_batch_free(batch);
}