# Rubinius WebAssembly VM
# Copyright (c) 2019-2020, Laurent Julliard and contributors
# All rights reserved.
#
# 4 bytes object array class
require_relative '../memory'
require_relative '../kernel'
require_relative '../object'
require_relative '../string'


class Array32
  attr_reader :count, :ptr

  # count: number of elements in Array
  # Array elements are native types or
  # pointers to objects
  # Arrays are fixed size for now
  def initialize(count)
    @ptr = Object.allocate(count * 4)
    @count = count
  end

  def size; @count; end
  def length; @count; end

  def [](idx)
    result :I32
    raise "Index out of bound" if idx >= @count
    # offset in memory for elt #idx is idx * 4
    Memory.load32(@ptr + (idx << 2))
  end

  def []=(idx, value)
    arg value: :I32
    result :I32
    raise "Index out of bound" if idx >= @count
    # offset in memory for elt #idx is idx * 4
    Memory.store32(@ptr + (idx << 2), value)
    value
  end

end