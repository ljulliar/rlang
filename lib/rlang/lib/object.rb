# Rubinius WebAssembly VM
# Copyright (c) 2019-2020, Laurent Julliard and contributors
# All rights reserved.
#
# Base Object class

require_relative './malloc'
require_relative './kernel'

class Object

  include Kernel
  
  def self.allocate(nbytes)
    result :I32
    Malloc.malloc(nbytes)
  end

  def self.free(object_ptr)
    result :none
    Malloc.free(object_ptr)
  end
end