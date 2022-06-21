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

  def to_s
    result :String
    "Object <addr>"
  end

  def object_id
    result :I32
    self
  end

  def eql?(object)
    result :I32
    inline wat: '(i32.eq 
      (local.get $_self_)
      (local.get $object))',
           wtype: :I32,
           ruby: 'self.object_id == object.object_id'
  end

  def ==(object)
    self.eql?(object)
  end

  def !=(object)
    !(self == object)
  end

end