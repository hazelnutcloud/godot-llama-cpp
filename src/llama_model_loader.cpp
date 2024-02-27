#include "llama_model_loader.h"
#include "llama_model.h"
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/classes/file_access.hpp>
#include <godot_cpp/classes/project_settings.hpp>

using namespace godot;

PackedStringArray LlamaModelLoader::_get_recognized_extensions() const {
	PackedStringArray arr;
	arr.push_back("gguf");
	return arr;
}

Variant godot::LlamaModelLoader::_load(const String &path, const String &original_path, bool use_sub_threads, int32_t cache_mode) const {
	Ref<LlamaModel> model = memnew(LlamaModel);

	if (!FileAccess::file_exists(path)) {
		return ERR_FILE_NOT_FOUND;
	}

	String absPath = ProjectSettings::get_singleton()->globalize_path(path);

	model->load_model(absPath);
	
	return { model };
}

bool LlamaModelLoader::_handles_type(const StringName &type) const {
  return ClassDB::is_parent_class(type, "LlamaModel");
}

String LlamaModelLoader::_get_resource_type(const String &p_path) const {
  String el = p_path.get_extension().to_lower();

  if (el == "gguf") {
    return "LlamaModel";
  }

  return "";
}