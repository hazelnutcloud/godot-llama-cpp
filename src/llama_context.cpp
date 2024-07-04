#include "llama_context.h"
#include "common.h"
#include "llama.h"
#include "llama_model.h"
#include <algorithm>
#include <godot_cpp/classes/engine.hpp>
#include <godot_cpp/classes/os.hpp>
#include <godot_cpp/classes/worker_thread_pool.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/utility_functions.hpp>

using namespace godot;

void LlamaContext::_bind_methods() {
	ClassDB::bind_method(D_METHOD("set_model", "model"), &LlamaContext::set_model);
	ClassDB::bind_method(D_METHOD("get_model"), &LlamaContext::get_model);
	ClassDB::add_property("LlamaContext", PropertyInfo(Variant::OBJECT, "model", PROPERTY_HINT_RESOURCE_TYPE, "LlamaModel"), "set_model", "get_model");

	ClassDB::bind_method(D_METHOD("get_seed"), &LlamaContext::get_seed);
	ClassDB::bind_method(D_METHOD("set_seed", "seed"), &LlamaContext::set_seed);
	ClassDB::add_property("LlamaContext", PropertyInfo(Variant::INT, "seed"), "set_seed", "get_seed");

	ClassDB::bind_method(D_METHOD("get_temperature"), &LlamaContext::get_temperature);
	ClassDB::bind_method(D_METHOD("set_temperature", "temperature"), &LlamaContext::set_temperature);
	ClassDB::add_property("LlamaContext", PropertyInfo(Variant::FLOAT, "temperature"), "set_temperature", "get_temperature");

	ClassDB::bind_method(D_METHOD("get_top_p"), &LlamaContext::get_top_p);
	ClassDB::bind_method(D_METHOD("set_top_p", "top_p"), &LlamaContext::set_top_p);
	ClassDB::add_property("LlamaContext", PropertyInfo(Variant::FLOAT, "top_p"), "set_top_p", "get_top_p");

	ClassDB::bind_method(D_METHOD("get_frequency_penalty"), &LlamaContext::get_frequency_penalty);
	ClassDB::bind_method(D_METHOD("set_frequency_penalty", "frequency_penalty"), &LlamaContext::set_frequency_penalty);
	ClassDB::add_property("LlamaContext", PropertyInfo(Variant::FLOAT, "frequency_penalty"), "set_frequency_penalty", "get_frequency_penalty");

	ClassDB::bind_method(D_METHOD("get_presence_penalty"), &LlamaContext::get_presence_penalty);
	ClassDB::bind_method(D_METHOD("set_presence_penalty", "presence_penalty"), &LlamaContext::set_presence_penalty);
	ClassDB::add_property("LlamaContext", PropertyInfo(Variant::FLOAT, "presence_penalty"), "set_presence_penalty", "get_presence_penalty");

	ClassDB::bind_method(D_METHOD("get_n_ctx"), &LlamaContext::get_n_ctx);
	ClassDB::bind_method(D_METHOD("set_n_ctx", "n_ctx"), &LlamaContext::set_n_ctx);
	ClassDB::add_property("LlamaContext", PropertyInfo(Variant::INT, "n_ctx"), "set_n_ctx", "get_n_ctx");

	ClassDB::bind_method(D_METHOD("get_n_len"), &LlamaContext::get_n_len);
	ClassDB::bind_method(D_METHOD("set_n_len", "n_len"), &LlamaContext::set_n_len);
	ClassDB::add_property("LlamaContext", PropertyInfo(Variant::INT, "n_len"), "set_n_len", "get_n_len");

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

	sampling_ctx = llama_sampling_init(sampling_params);

	UtilityFunctions::print(vformat("%s: Context initialized", __func__));

	thread->start(callable_mp(this, &LlamaContext::__thread_loop));
}

void LlamaContext::__thread_loop() {
	while (true) {
		semaphore->wait();

		mutex->lock();
		if (exit_thread) {
			mutex->unlock();
			break;
		}
		if (completion_requests.size() == 0) {
			mutex->unlock();
			continue;
		}
		completion_request req = completion_requests.get(0);
		completion_requests.remove_at(0);
		mutex->unlock();

		UtilityFunctions::print(vformat("%s: Running completion for prompt id: %d", __func__, req.id));

		std::vector<llama_token> request_tokens;
		request_tokens = ::llama_tokenize(ctx, req.prompt.utf8().get_data(), true, true);

		size_t shared_prefix_idx = 0;
		auto diff = std::mismatch(context_tokens.begin(), context_tokens.end(), request_tokens.begin(), request_tokens.end());
		if (diff.first != context_tokens.end()) {
			shared_prefix_idx = std::distance(context_tokens.begin(), diff.first);
		} else {
			shared_prefix_idx = std::min(context_tokens.size(), request_tokens.size());
		}

		bool rm_success = llama_kv_cache_seq_rm(ctx, -1, shared_prefix_idx, -1);
		if (!rm_success) {
			UtilityFunctions::printerr(vformat("%s: Failed to remove tokens from kv cache", __func__));
			Dictionary response;
			response["id"] = req.id;
			response["error"] = "Failed to remove tokens from kv cache";
			call_thread_safe("emit_signal", "completion_generated", response);
			continue;
		}
		context_tokens.erase(context_tokens.begin() + shared_prefix_idx, context_tokens.end());
		request_tokens.erase(request_tokens.begin(), request_tokens.begin() + shared_prefix_idx);

		int32_t batch_size = std::min(ctx_params.n_batch, (uint32_t)request_tokens.size());

		llama_batch batch = llama_batch_init(batch_size, 0, 1);

		// chunk request_tokens into sequences of size batch_size
		std::vector<std::vector<llama_token>> sequences;
		for (size_t i = 0; i < request_tokens.size(); i += batch_size) {
			sequences.push_back(std::vector<llama_token>(request_tokens.begin() + i, request_tokens.begin() + std::min(i + batch_size, request_tokens.size())));
		}

		printf("Request tokens: \n");
		for (auto sequence : sequences) {
			for (auto token : sequence) {
				printf("%s", llama_token_to_piece(ctx, token).c_str());
			}
		}
		printf("\n");

		int curr_token_pos = context_tokens.size();
		bool decode_failed = false;

		for (size_t i = 0; i < sequences.size(); i++) {
			llama_batch_clear(batch);

			std::vector<llama_token> sequence = sequences[i];

			for (size_t j = 0; j < sequence.size(); j++) {
				llama_batch_add(batch, sequence[j], j + curr_token_pos, { 0 }, false);
			}

			curr_token_pos += sequence.size();

			if (i == sequences.size() - 1) {
				batch.logits[batch.n_tokens - 1] = true;
			}

			if (llama_decode(ctx, batch) != 0) {
				decode_failed = true;
				break;
			}
		}

		printf("Request tokens: %d\n", (int32_t)request_tokens.size());
		printf("Batch tokens: %d\n", batch.n_tokens);
		printf("Current token pos: %d\n", curr_token_pos);

		if (decode_failed) {
			Dictionary response;
			response["id"] = req.id;
			response["error"] = "llama_decode() failed";
			call_thread_safe("emit_signal", "completion_generated", response);
			continue;
		}

		context_tokens.insert(context_tokens.end(), request_tokens.begin(), request_tokens.end());

		while (true) {
			if (exit_thread) {
				return;
			}
			llama_token new_token_id = llama_sampling_sample(sampling_ctx, ctx, NULL, batch.n_tokens - 1);
			llama_sampling_accept(sampling_ctx, ctx, new_token_id, false);

			Dictionary response;
			response["id"] = req.id;

			context_tokens.push_back(new_token_id);

			bool eog = llama_token_is_eog(model->model, new_token_id);
			bool curr_eq_n_len = curr_token_pos == n_len;

			if (eog || curr_eq_n_len) {
				response["done"] = true;
				call_thread_safe("emit_signal", "completion_generated", response);
				break;
			}

			response["text"] = llama_token_to_piece(ctx, new_token_id).c_str();
			response["done"] = false;
			call_thread_safe("emit_signal", "completion_generated", response);

			llama_batch_clear(batch);

			llama_batch_add(batch, new_token_id, curr_token_pos, { 0 }, true);

			curr_token_pos++;

			if (llama_decode(ctx, batch) != 0) {
				decode_failed = true;
				break;
			}
		}

		llama_sampling_reset(sampling_ctx);

		if (decode_failed) {
			Dictionary response;
			response["id"] = req.id;
			response["error"] = "llama_decode() failed";
			call_thread_safe("emit_signal", "completion_generated", response);
			continue;
		}
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

int LlamaContext::get_n_len() {
	return n_len;
}
void LlamaContext::set_n_len(int n_len) {
	this->n_len = n_len;
}

float LlamaContext::get_temperature() {
	return sampling_params.temp;
}
void LlamaContext::set_temperature(float temperature) {
	sampling_params.temp = temperature;
}

float LlamaContext::get_top_p() {
	return sampling_params.top_p;
}
void LlamaContext::set_top_p(float top_p) {
	sampling_params.top_p = top_p;
}

float LlamaContext::get_frequency_penalty() {
	return sampling_params.penalty_freq;
}
void LlamaContext::set_frequency_penalty(float frequency_penalty) {
	sampling_params.penalty_freq = frequency_penalty;
}

float LlamaContext::get_presence_penalty() {
	return sampling_params.penalty_present;
}
void LlamaContext::set_presence_penalty(float presence_penalty) {
	sampling_params.penalty_present = presence_penalty;
}

void LlamaContext::_exit_tree() {
	if (Engine::get_singleton()->is_editor_hint()) {
		return;
	}

	mutex->lock();
	exit_thread = true;
	mutex->unlock();

	semaphore->post();

	thread->wait_to_finish();

	if (ctx) {
		llama_free(ctx);
	}

	llama_sampling_free(sampling_ctx);
	llama_backend_free();
}