#ifndef LLAMA_MODEL_LOADER_H
#define LLAMA_MODEL_LOADER_H

#include <godot_cpp/classes/resource_format_loader.hpp>

namespace godot {

class LlamaModelLoader : public ResourceFormatLoader {
	GDCLASS(LlamaModelLoader, ResourceFormatLoader)

protected:
	static void _bind_methods(){};

public:
	PackedStringArray _get_recognized_extensions() const override;
	Variant _load(const String &path, const String &original_path, bool use_sub_threads, int32_t cache_mode) const override;
};

} //namespace godot

#endif