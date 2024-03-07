#include "llama_context.h"
#include "common.h"
#include "llama.h"
#include "llama_model.h"
#include <godot_cpp/classes/engine.hpp>
#include <godot_cpp/classes/os.hpp>
#include <godot_cpp/classes/worker_thread_pool.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/utility_functions.hpp>

using namespace godot;

void LlamaContext::_bind_methods() {
	ClassDB::bind_method(D_METHOD("set_model", "model"), &LlamaContext::set_model);
	ClassDB::bind_method(D_METHOD("get_model"), &LlamaContext::get_model);
	ClassDB::add_property("LlamaContext", PropertyInfo(Variant::OBJECT, "model", PROPERTY_HINT_RESOURCE_TYPE, "LlamaModel"), "set_model", "get_model");
	ClassDB::bind_method(D_METHOD("request_completion", "prompt"), &LlamaContext::request_completion);
	ClassDB::bind_method(D_METHOD("_fulfill_completion", "prompt"), &LlamaContext::_fulfill_completion);
	ADD_SIGNAL(MethodInfo("completion_generated", PropertyInfo(Variant::STRING, "completion"), PropertyInfo(Variant::BOOL, "is_final")));
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

	ctx_params.seed = -1;
	ctx_params.n_ctx = 4096;
	int32_t n_threads = OS::get_singleton()->get_processor_count();
	ctx_params.n_threads = n_threads;
	ctx_params.n_threads_batch = n_threads;

	ctx = llama_new_context_with_model(model->model, ctx_params);
	if (ctx == NULL) {
		UtilityFunctions::printerr(vformat("%s: Failed to initialize llama context, null ctx", __func__));
		return;
	}
	UtilityFunctions::print(vformat("%s: Context initialized", __func__));
}

Variant LlamaContext::request_completion(const String &prompt) {
	UtilityFunctions::print(vformat("%s: Requesting completion for prompt: %s", __func__, prompt));
	if (task_id) {
		WorkerThreadPool::get_singleton()->wait_for_task_completion(task_id);
	}
	task_id = WorkerThreadPool::get_singleton()->add_task(Callable(this, "_fulfill_completion").bind(prompt));
	return OK;
}

void LlamaContext::_fulfill_completion(const String &prompt) {
	UtilityFunctions::print(vformat("%s: Fulfilling completion for prompt: %s", __func__, prompt));
	std::vector<llama_token> tokens_list;
	tokens_list = ::llama_tokenize(ctx, std::string(prompt.utf8().get_data()), true);

	const int n_len = 128;
	const int n_ctx = llama_n_ctx(ctx);
	const int n_kv_req = tokens_list.size() + (n_len - tokens_list.size());
	if (n_kv_req > n_ctx) {
		UtilityFunctions::printerr(vformat("%s: n_kv_req > n_ctx, the required KV cache size is not big enough\neither reduce n_len or increase n_ctx", __func__));
		return;
	}

	for (size_t i = 0; i < tokens_list.size(); i++) {
		llama_batch_add(batch, tokens_list[i], i, { 0 }, false);
	}

	batch.logits[batch.n_tokens - 1] = true;

	llama_kv_cache_clear(ctx);

	int decode_res = llama_decode(ctx, batch);
	if (decode_res != 0) {
		UtilityFunctions::printerr(vformat("%s: Failed to decode prompt with error code: %d", __func__, decode_res));
		return;
	}

	int n_cur = batch.n_tokens;
	int n_decode = 0;
	llama_model *llama_model = model->model;

	while (n_cur <= n_len) {
		// sample the next token
		{
			auto n_vocab = llama_n_vocab(llama_model);
			auto *logits = llama_get_logits_ith(ctx, batch.n_tokens - 1);

			std::vector<llama_token_data> candidates;
			candidates.reserve(n_vocab);

			for (llama_token token_id = 0; token_id < n_vocab; token_id++) {
				candidates.emplace_back(llama_token_data{ token_id, logits[token_id], 0.0f });
			}

			llama_token_data_array candidates_p = { candidates.data(), candidates.size(), false };

			// sample the most likely token
			const llama_token new_token_id = llama_sample_token_greedy(ctx, &candidates_p);

			// is it an end of stream?
			if (new_token_id == llama_token_eos(llama_model) || n_cur == n_len) {
				call_thread_safe("emit_signal", "completion_generated", "\n", true);

				break;
			}

			call_thread_safe("emit_signal", "completion_generated", vformat("%s", llama_token_to_piece(ctx, new_token_id).c_str()), false);

			// prepare the next batch
			llama_batch_clear(batch);

			// push this new token for next evaluation
			llama_batch_add(batch, new_token_id, n_cur, { 0 }, true);

			n_decode += 1;
		}

		n_cur += 1;

		// evaluate the current batch with the transformer model
		int decode_res = llama_decode(ctx, batch);
		if (decode_res != 0) {
			UtilityFunctions::printerr(vformat("%s: Failed to decode batch with error code: %d", __func__, decode_res));
			break;
		}
	}
}

void LlamaContext::set_model(const Ref<LlamaModel> p_model) {
	model = p_model;
}

Ref<LlamaModel> LlamaContext::get_model() {
	return model;
}

LlamaContext::~LlamaContext() {
	if (ctx) {
		llama_free(ctx);
	}

	llama_batch_free(batch);

	if (task_id) {
		WorkerThreadPool::get_singleton()->wait_for_task_completion(task_id);
	}
}