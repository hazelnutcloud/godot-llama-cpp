#include "llama.h"
#include "llama_backend.h"
#include <godot_cpp/core/class_db.hpp>

using namespace godot;

void LlamaBackend::_enter_tree() {
  llama_backend_init();
}

void LlamaBackend::_exit_tree() {
  llama_backend_free();
}