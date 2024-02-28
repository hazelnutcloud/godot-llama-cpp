#ifndef LLAMA_BACKEND_H
#define LLAMA_BACKEND_H

#include <godot_cpp/classes/ref_counted.hpp>

namespace godot {
class LlamaBackend : public RefCounted {
	GDCLASS(LlamaBackend, RefCounted)

protected:
	static void _bind_methods();

public:
  void init();
  void deinit();
};
} //namespace godot

#endif