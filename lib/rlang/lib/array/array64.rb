# Rubinius WebAssembly VM
# Copyright (c) 2019-2020, Laurent Julliard and contributors
# All rights reserved.
#
# 4 bytes object array class
require_relative '../memory'
require_relative '../kernel'
require_relative '../object'
require_relative '../string'


class Array64
  attr_reader :count, :ptr

  # count: number of elements in Array
  # Array elements are native types or
  # pointers to objects
  # Arrays are fixed size for now
  def initialize(count)
    @ptr = Object.allocate(count * 8)
    @count = count
  end

  def size; @count; end
  def length; @count; end

  def [](idx)
    result :I64
    raise "Index out of bound" if idx >= @count
    # offset in memory for elt #idx is idx * 8
    Memory.load64(@ptr + (idx << 3))
  end

  def []=(idx, value)
    arg value: :I64
    result :I64
    raise "Index out of bound" if idx >= @count
    # offset in memory for elt #idx is idx * 8
    Memory.store64(@ptr + (idx << 3), value)
    value
  end

end