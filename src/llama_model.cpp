#include "llama_model.h"
#include "llama.h"
#include <godot_cpp/core/class_db.hpp>

using namespace godot;

void LlamaModel::load_model(const String &path) {
  if (model) {
    llama_free_model(model);
  }
  llama_model_params model_params = llama_model_default_params();
	model = llama_load_model_from_file(path.utf8().get_data(), model_params);
}

void LlamaModel::_bind_methods() {
  ClassDB::bind_method(D_METHOD("load_model", "path"), &LlamaModel::load_model);
}

LlamaModel::~LlamaModel() {
  if (model) {
    llama_free_model(model);
  }
}