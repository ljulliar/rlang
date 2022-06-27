
# Rlang language, compiler and libraries
# Copyright (c) 2019-2022,Laurent Julliard and contributors
# All rights reserved.
#
# mimic the sbrk Unix function, requesting n more bytes
# sbrk(n) returns the address of the allocated block or -1 if it failed
# srbk(0) returns the current value of the break
# Note: in WASM we can only grow linear memory by pages (64 KB block)

require_relative './memory'

# These 3 global variables below are used by the
# dynamic memory allocator. You can redefine them
# in your own module

# Heap base address (make sure it's aligned on 
# an address compatible with the most restrictive data type
# used in WASM (I64). So make this address a multiple of 8
$HEAP = 1024

# Maximum amount of memory the heap can grow
# NOTE: must be less than the upper WASM memory limit (4GB)
$HEAP_MAX_SIZE = 1073741824  # 1GB

# Current heap size (starts at 0, the first malloc will
# set it up)
$HEAP_SIZE = 0

class Unistd

  def self.sbrk(n)
    # local variables used. All default type
    # wasm_mem_size:  current wasm memory size (in bytes)
    # heap_break:     current heap break
    #
    # new_heap_size:  new heap size (HEAP_SIZE + n)
    # new_heap_break: new heap break (HEAP + HEAP_SIZE + n)
    # more_pages:     how many more WASM pages are needed

    # return current break if n is 0
    heap_break = $HEAP + $HEAP_SIZE
    return heap_break if n == 0

    # check if new heap size is beyond authorized limit
    new_heap_size = $HEAP_SIZE + n
    return -1 if new_heap_size >= $HEAP_MAX_SIZE

    # We are good, so now check if we need more WASM 
    # memory pages (1 page = 64 KB)
    wasm_mem_size = Memory.size * 65536
    new_heap_break = heap_break + n

    # need to grow memory? if so by how many WASM pages ?
    if new_heap_break >= wasm_mem_size
      more_pages = (new_heap_break - wasm_mem_size) / 65536 + 1
    end

    # go grow WASM memory by so many pages. Return -1 if it fails
    return -1 if Memory.grow(more_pages) == -1
  
    # set new heap size
    $HEAP_SIZE = new_heap_size
  
    # heap_break is the address where the new free space starts
    return heap_break
  end
end
