# Rlang : a (subset of) Ruby to WebAssembly compiler

Rlang is meant to create fast and uncluttered [WebAssembly](https://webassembly.org) code from the comfort of the Ruby language.

Rlang actually two things: 1) a subset of the Ruby language and 2) a **compiler** transforming this Ruby subset in a valid, fully runnable and native WebAssembly module.

Rlang can be seen as a foundational language that can help you quickly develop and debug high performance WebAssembly modules. For the rationale behind the creation of Rlang see [below](#why-rlang).

What you'll find in the current version is a first implementation of Rlang. It will improve over time, with more facilities and probably more Ruby features but always with the goal to generate crisp and uncluttered WAT code.

## Dependencies

* **WABT toolit**: the rlang compiler can generate both WebAssembly source code (WAT file) and WebAssembly bytecode (WASM file). To generate WASM bytecode the rlang compiler uses wat2wasm. This utility is part of the [WABT toolkit](https://github.com/WebAssembly/wabt)
* **wasmer runtime** (optional): [Wasmer](https://wasmer.io/) is a fast WebAssembly runtime. You'll need it if you want to run the test suite from the source repo. You can also use it to run the compiled WASM code generated by the rlang compiler. You can get Wasmer at  [wasmer.io](https://wasmer.io/)


## Installing Rlang
Rlang is available as a gem from rubygems.org. So simply run the following command to install it:

```
$ gem install rlang
```
Alternatively, if you clone this git repo and play with the Rlang source code you can generate your own local gem and install it like this:

```
$ gem build rlang.gemspec
$ gem install --local rlang-x.y.z.gem
```

To check that the installation went well, run `rlang --help` and see if the help message displays correctly

## The Rlang language
Ruby features supported by Rlang are detailed in the [Rlang Manual](https://github.com/ljulliar/rlang/blob/master/docs/RlangManual.md)

You can also look at the rlang test suite in [test/rlang_test_files](https://github.com/ljulliar/rlang/blob/master/test/rlang_test_files/) to get a flavor of the subset of Ruby currently supported.

## rlang compiler
The Rlang compiler can be invoked through the `rlang` command. See the [Rlang Compiler Documentation](https://github.com/ljulliar/rlang/blob/master/docs/RlangCompiler.md) for more details about the command line options.

Keep in mind that Rlang is **NOT** a Ruby interpreter or a Ruby VM executing some kind of bytecode. It does actually statically **compile** the Rlang language to WebAssembly code pretty much like gcc or llvm compiles C/C++ code to machine assembly language.

## rlang simulator
**COMING SOON**
One of the big benefits of Rlang being a subset of the Ruby language is that you can actually run, test and debug your Rlang code as you would for normal Ruby code. This can be a big boost for your productivity.

## Why Rlang?
This project was created out of the need to develop a Virtual Machine written in WebAssembly capable of interpreting the [Rubinius](https://github.com/rubinius/rubinius) bytecode. And yes, ultimately run a native Ruby VM in a browser :-)

After a first proof of concept written directly by hand in WebAssembly (WAT code) it became clear that writing a full fledged VM directly in WebAssembly was going to be tedious, complex and unnecessarily painful.

Sure I could have written this VM in any of the language that can already be compiled directly to WebAssembly (C, C++, Rust, Go,...) but being fond of Ruby since 2000 I decided that I would go for a compiler capable of transforming a subset of the Ruby language directly into WebAssembly with a minimum overhead. So in a nutshell: the goal of Rlang is to let you develop efficient WebAssembly code with a reasonably high level of abstraction while keeping the generated WebAssembly code straightforward and human readable.

## Why the name Rlang?
Yes I hear you: Rlang is already the name of the R language so why use that name and aren't you introducing some confusion? Well for one I couldn't resist using that name to honor software engineering history (see below) and because, after all, the intersection between the Ruby/WebAssembly community and the R language community focused on data processing and machine learning must be quite small to say the least.

The name **Rlang** itself is  a tribute to [Slang](http://wiki.squeak.org/squeak/slang), a subset of the Smalltalk language that can directly translate to C. It was created in 1995 to bootstrap the development of the virtual machine of Squeak, an open-source Smalltalk programming system. I highly encourage anyone interested in the history and the technology of virtual machines to read both the [Back to the future](http://www.vpri.org/pdf/tr1997001_backto.pdf) article as well as the now legendary [Blue Book](http://stephane.ducasse.free.fr/FreeBooks/BlueBook/Bluebook.pdf) explaining how the Smalltalk-80 Virtual Machine and Language were designed in the 80s. I would actually go as far as saying that you don't really know what (virtual) machines are until you have read this book :-)

## Credits
A big thanks to:
* [@whitequark](https://github.com/whitequark) for a fantastic [Ruby parser](https://github.com/whitequark/parser)
* The [Wasmer](https://wasmer.io/) team as well as the author of the [Ruby Wasm extension of Wasmer](https://github.com/wasmerio/ruby-ext-wasm)
