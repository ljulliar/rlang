# Rlang
A (subset of) Ruby to WebAssembly compiler

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
This project was created out of the need to develop a Virtual Machine written in WebAssembly capable of interpreting the [Rubinius](https://github.com/rubinius/rubinius) bytecode. After a first proof of concept written directly by hand in WebAssembly (WAT Code) it became clear that writing a full fledged VM directly in WebAssembly was going to be tedious and complex.

Sure I could have written this VM in any of the language that can already be compiled directly to WebAssembly (C, C++, Rust, Go,...) but being fond of Ruby since 2000 I decided that I would go for a compiler (Rlang) capable of transforming a subset of the Ruby language directly into WebAssembly with a minimum overhead.

The name **Rlang** itself is a nod to [Slang](http://wiki.squeak.org/squeak/slang), a subset of the Smalltalk language that can directly translate to C and was [invented in 1995](http://www.vpri.org/pdf/tr1997001_backto.pdf) to bootstrap the development of the Squeak VM, an open-source Smalltalk programming system
