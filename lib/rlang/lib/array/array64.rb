# Rubinius WebAssembly VM
# Copyright (c) 2019-2020, Laurent Julliard and contributors
# All rights reserved.
#
# 4 bytes object array class
require_relative '../memory'
require_relative '../object'
require_relative '../type'
require_relative '../string'


class Array64
  attr_reader :count, :ptr

  # count: number of elements in Array
  # Array elements are native types or
  # pointers to objects
  # Arrays are fixed size for now
  def initialize(count)
    # Avoid allocating 0 bytes in memory
    if count == 0
      @ptr = 0
    else
      # Memory size is count * 8 bytes
      @ptr = Object.allocate(count << 3)
    end
    @count = count
  end

  def size; @count; end
  def length; @count; end
  def empty?; self.size == 0; end

  def [](idx)
    result :I64
    raise "Index out of bound" if idx >= @count || idx < -@count
    # offset in memory for elt #idx is idx * 8
    Memory.load64(@ptr + (idx << 3))
  end

  def []=(idx, value)
    arg value: :I64
    result :I64
    raise "Index out of bound" if idx >= @count || idx < -@count
    # offset in memory for elt #idx is idx * 8
    Memory.store64(@ptr + (idx << 3), value)
    value
  end

  def free
    result :none
    Object.free(@ptr)
    Object.free(self)
  end

end