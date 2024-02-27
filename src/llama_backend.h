#ifndef LLAMA_BACKEND_H
#define LLAMA_BACKEND_H

#include <godot_cpp/classes/node.hpp>

namespace godot {
class LlamaBackend : public Node {
	GDCLASS(LlamaBackend, Node)

protected:
	static void _bind_methods(){};

public:
  virtual void _enter_tree() override;
  virtual void _exit_tree() override;
};
} //namespace godot

#endif