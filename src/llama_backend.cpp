#include "llama.h"
#include "llama_backend.h"
#include <godot_cpp/core/class_db.hpp>

using namespace godot;

void LlamaBackend::init() {
  llama_backend_init();
  llama_numa_init(ggml_numa_strategy::GGML_NUMA_STRATEGY_DISABLED);
}

void LlamaBackend::deinit() {
  llama_backend_free();
}

void LlamaBackend::_bind_methods() {
  ClassDB::bind_method(D_METHOD("init"), &LlamaBackend::init);
  ClassDB::bind_method(D_METHOD("deinit"), &LlamaBackend::deinit);
}