# Rubinius WebAssembly VM
# Copyright (c) 2019-2020, Laurent Julliard and contributors
# All rights reserved.
#
# This is just a minimal Rlang file to require
# malloc and then instantiate it int he Wasmer 
# run time

# These 3 global variables below are used by the
# dynamic memory allocator. They must however be 
# defined in the end applications.

# Heap base address (make sure it's aligned on 
# an address compatible with the most restrictive data type
# used in WASM (I64). So make this address a multiple of 8
$HEAP = 10024

# Maximum amount of memory the heap can grow
# NOTE: must be less than the upper WASM memory limit (4GB)
$HEAP_MAX_SIZE = 1073741824  # 1GB

# Current heap size (starts at 0, the first malloc will
# set it up)
$HEAP_SIZE = 0

require 'rlang/lib'

# Create methods to access globals from Wasm runtime
# as they cannot be exported by Wasmer
# (TODO: double check that actually)
class Global
  export
  def self.heap; $HEAP; end

  export
  def self.heap_size; $HEAP_SIZE; end
end

class Malloc
  export
  def self.freep
    result :Header
    @@freep
  end
end

