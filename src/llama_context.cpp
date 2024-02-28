#include "llama_context.h"
#include "llama.h"
#include "llama_model.h"
#include <godot_cpp/classes/engine.hpp>
#include <godot_cpp/classes/os.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/utility_functions.hpp>

using namespace godot;

void LlamaContext::set_model(const Ref<LlamaModel> p_model) {
	model = p_model;
}

Ref<LlamaModel> LlamaContext::get_model() {
	return model;
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

	ctx_params.n_ctx = 2048;
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

LlamaContext::~LlamaContext() {
	if (ctx) {
		llama_free(ctx);
	}
}

void LlamaContext::_bind_methods() {
	ClassDB::bind_method(D_METHOD("set_model", "model"), &LlamaContext::set_model);
	ClassDB::bind_method(D_METHOD("get_model"), &LlamaContext::get_model);
	ClassDB::add_property("LlamaContext", PropertyInfo(Variant::OBJECT, "model", PROPERTY_HINT_RESOURCE_TYPE, "LlamaModel"), "set_model", "get_model");
}