# The Rlang compiler

The Rlang compiler can be invoked with the `rlang` command. It takes a Rlang source file as an argument and can generate three types of output:
* Ruby AST: the `--ast` option generates an abstract syntax tree of your Rlang code
* WAT code: the `--wat` option turns your Rlang code into WebAssembly source code
* WASM bytecode: the `--wasm` first compile your Rlang code to WAT code and then turns it into WebAssembly bytecode that can be executed from within a WebAssembly runtime of your choice.

Make sure that the [WABT toolkit](https://github.com/WebAssembly/wabt) is installed before using the `--wasm` option. 

### Rlang compiler options
Here is the output of `rlang --help` command:

```
Usage: rlang [options] rlang_file.rb
    -I, --load_path DIRECTORY        specify $LOAD_PATH directory (may be used more than once)
    -M, --module NAME                WASM module name
    -m, --memory MIN[,MAX]           WASM Memory size allocated in pages (MIN default is 4)
    -w, --wat                        Generate WAT source file
    -a, --ast                        Generate Ruby AST file
    -s, --wasm                       Generate WASM bytecode file
    -o, --output FILE                Write output to file
    -v, --verbose [LEVEL]            Verbosity level (fatal, error, warn, info, debug)
    -V, --version                    Displays Rlang version
    -h, --help                       Prints this help
```
* **-I, --load_path DIRECTORY**: this option can be used several time to append several directories to the Rlang path. Please note that the Rlang load path doesn't inherit from the regular Ruby load path
* **-M, --module**: allows to specify a name for the generated WebAssembly module. By default it doesn't have any.
* **-m, --memory MIN[,MAX]**: size of the WASM memory allocated at run time. The first argument is the initial amount of memory allocated and the second one (optional) is the maximum memory that your WASM module can allocate while running. The unit of both arguments is in number of WASM pages (4 KBytes)
* **-w, --wat**: parse Rlang file and generate WAT source code
* **-a, --ast**: parse Rlang file and generate the Ruby abstract syntax tree
* **-w, --wat**: parse Rlang file, generate WAT source code and compile it to WASM bytecode
* **-o, --output FILE**: send rlang output to FILE
* **-v, --verbose [LEVEL]**: verbosity level (fatal, error, warn, info, debug). Default is warn
* **-V, --version**: Displays Rlang version
* **-h, --help**: Prints help message
