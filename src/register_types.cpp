#include "register_types.h"
#include <gdextension_interface.h>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/core/defs.hpp>
#include <godot_cpp/godot.hpp>
#include <godot_cpp/classes/resource_loader.hpp>
#include "llama_model.h"
#include "llama_model_loader.h"
#include "llama_context.h"
#include "llama_backend.h"

using namespace godot;

static Ref<LlamaModelLoader> llamaModelLoader;

void initialize_types(ModuleInitializationLevel p_level)
{
	if (p_level != MODULE_INITIALIZATION_LEVEL_SCENE) {
		return;
	}
	ClassDB::register_class<LlamaModelLoader>();
	llamaModelLoader.instantiate();
	ResourceLoader::get_singleton()->add_resource_format_loader(llamaModelLoader);

	ClassDB::register_class<LlamaModel>();
  ClassDB::register_class<LlamaContext>();
  ClassDB::register_class<LlamaBackend>();
}

void uninitialize_types(ModuleInitializationLevel p_level) {
	if (p_level != MODULE_INITIALIZATION_LEVEL_SCENE) {
		return;
	}
	ResourceLoader::get_singleton()->remove_resource_format_loader(llamaModelLoader);
	llamaModelLoader.unref();
}

extern "C"
{
	// Initialization
	GDExtensionBool GDE_EXPORT init_library(GDExtensionInterfaceGetProcAddress p_get_proc_address, GDExtensionClassLibraryPtr p_library, GDExtensionInitialization *r_initialization)
	{
		GDExtensionBinding::InitObject init_obj(p_get_proc_address, p_library, r_initialization);
		init_obj.register_initializer(initialize_types);
		init_obj.register_terminator(uninitialize_types);
		init_obj.set_minimum_library_initialization_level(MODULE_INITIALIZATION_LEVEL_SCENE);

		return init_obj.init();
	}
}