# Rlang : a (subset of) Ruby to WebAssembly compiler

Rlang is meant to create fast and uncluttered [WebAssembly](https://webassembly.org) code from the comfort of the Ruby language.

Rlang is not a new language and it is not intended to be a general purpose languange. It is actually two things: a supported subset of the Ruby language and a compiler ("translator" would actually be more appropriate) transforming this Ruby subset in a valid and fully runnable WebAssembly module.

Rlang can be seen as a foundational language that can help you quickly develop and debug high performance WebAssembly modules. For the rationale behind the creation of Rlang see below.

## Supported subset of Ruby
TBD
supported instructions
supported types
type cast

## rlang compiler
TBD
## rlang simulator
TBD

## Why Rlang?
This project was created out of the need to develop a Virtual Machine written in WebAssembly capable of interpreting the [Rubinius](https://github.com/rubinius/rubinius) bytecode. And yes, ultimately running a native Ruby VM in a browser :-)

After a first proof of concept written directly by hand in WebAssembly (WAT code) it became clear that writing a full fledged VM directly in WebAssembly was going to be tedious, complex and un-necessarily painful.

Sure I could have written this VM in any of the language that can already be compiled directly to WebAssembly (C, C++, Rust, Go,...) but being fond of Ruby since 2000 I decided that I would go for a compiler (Rlang) capable of transforming a subset of the Ruby language directly into WebAssembly with a minimum overhead. So in a nutshell: the goal of Rlang is to let you develop efficient WebAssembly code with a reasonably high level of abstraction while keeping the generated WebAssembly code straightforward.

The name **Rlang** itself is also a tribute to [Slang](http://wiki.squeak.org/squeak/slang), a subset of the Smalltalk language that can directly translate to C. It was [created in 1995] to bootstrap the development of the Squeak VM, an open-source Smalltalk programming system. I highly encourage anyone interested in the history and the technology of virtual machines to read the both the [Back to the future article](http://www.vpri.org/pdf/tr1997001_backto.pdf) and the legendary [Blue Book](http://stephane.ducasse.free.fr/FreeBooks/BlueBook/Bluebook.pdf). I would actually go as far as saying that you don't really know what (virtual) machines are until you have read this book :-)
