#include "llama_model.h"
#include "llama.h"
#include <godot_cpp/classes/project_settings.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/utility_functions.hpp>
#include <godot_cpp/classes/engine.hpp>

using namespace godot;

void LlamaModel::_bind_methods() {
	ClassDB::bind_method(D_METHOD("load_model"), &LlamaModel::load_model);

	ClassDB::bind_method(D_METHOD("get_n_gpu_layers"), &LlamaModel::get_n_gpu_layers);
	ClassDB::bind_method(D_METHOD("set_n_gpu_layers", "n"), &LlamaModel::set_n_gpu_layers);
	ClassDB::add_property("LlamaModel", PropertyInfo(Variant::INT, "n_gpu_layers"), "set_n_gpu_layers", "get_n_gpu_layers");
}

LlamaModel::LlamaModel() {
	model_params = llama_model_default_params();
}

void LlamaModel::load_model() {
	if (model) {
		return;
	}

	if (Engine::get_singleton()->is_editor_hint()) {
		return;
	}

	String absPath = ProjectSettings::get_singleton()->globalize_path(get_path());

	model = llama_load_model_from_file(absPath.utf8().get_data(), model_params);

	if (model == NULL) {
		UtilityFunctions::printerr(vformat("%s: Unable to load model from %s", __func__, absPath));
		return;
	}

	UtilityFunctions::print(vformat("%s: Model loaded from %s", __func__, absPath));
}

int32_t LlamaModel::get_n_gpu_layers() {
	return model_params.n_gpu_layers;
}

void LlamaModel::set_n_gpu_layers(int32_t n) {
	model_params.n_gpu_layers = n;
}

LlamaModel::~LlamaModel() {
	if (model) {
		llama_free_model(model);
	}
}