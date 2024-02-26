import sys
from godot_cpp import binding_generator
from pathlib import Path
from os.path import abspath

if __name__ == "__main__":
    if len(sys.argv) < 3:
        print("Please provide the path to the godot extension_api.json file and the output directory")
        exit(1)
  
    if sys.argv[1] is None:
        print("Please provide the path to the godot extension_api.json file")
        exit(1)

    if sys.argv[2] is None:
        print("Please provide the path to the output directory")
        exit(1)
        
    api_filepath = Path(sys.argv[1]).resolve()
    output_dir = abspath(Path(sys.argv[2]).resolve())
    
    binding_generator.generate_bindings(
        api_filepath=api_filepath, use_template_get_node=True, output_dir=output_dir
    )
