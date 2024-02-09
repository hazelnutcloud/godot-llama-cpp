#include "llama.h"
#include "common.h"
#include "llama_model.h"
#include <godot_cpp/core/class_db.hpp>

using namespace godot;

void LlamaModel::_bind_methods() {
}

LlamaModel::LlamaModel() {
	llama_model_params model_params = llama_model_default_params();
	model = llama_load_model_from_file(resource_path, model_params);

	if (model == NULL) {
		ERR_FAIL_NULL_MSG(model, "Unable to load model");
	}
}

LlamaModel::~LlamaModel() {
	llama_free_model(model);
}