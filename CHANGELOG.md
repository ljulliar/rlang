## 0.6.0
* Support for signed/unsigned integers (arithmetics, relational operatos, explicit and implicit type cast)
* More methods in String ([], []=, +, *, ==, !=, chr,...)
* More methods in Array  ([], []=, ==, !=,...)
* More methods in I32 and I64 classes (to_s,...)
* Base 64 encoding and decidong module (same methods as in Ruby)
* Array literal ([]) supported as initializer
* Automatically adjust HEAP base address at compile time
* Various bug fixes and code cleanup

## 0.5.1
* Imported WASM methods can now be defined
* Preliminary version of WASI interface and IO class added to Rlang library

## 0.5.0
* Class attributes syntax now identical to plain Ruby
* Class in class definition and module supported
* Class inheritance
* Basic Array and String class in Rlang library

## 0.4.0
* Object instances, instance methods and instance variables now supported
* Test suite using parser directly
* Code coverage is enabled in test suite

## 0.3.1
* Add ruby parser as runtime dependency in gemspec
* DAta directive documented in Rlang manual

## 0.3.0
* First published release on rubygems.org
