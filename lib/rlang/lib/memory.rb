# Rlang language, compiler and libraries
# Copyright (c) 2019-2022, Laurent Julliard and contributors
# All rights reserved.
#
# Web Assembly memory access methods
#

class Memory

  def self.size
    inline wat: '(memory.size)'
  end

  def self.grow(delta)
    inline wat: '(memory.grow (local.get $delta))'
  end

  # Copy memory from source to destination address
  # TODO: optimize this method using 64 bits copy
  # first then 32 bits, then 16, then 8 bits
  def self.copy(src, dest, size)
    arg src: :I32, dest: :I32
    result :none
    idx = 0
    while idx < size
      inline wat: '(i32.store8 
      (i32.add (local.get $dest) (local.get $idx))
      (i32.load8_u (i32.add (local.get $src) (local.get $idx)))
      )', wtype: :none
      idx += 1
    end
  end

  def self.load32_8(addr)
    arg addr: :I32
    result :I32
    inline wat: '(i32.load8_u (local.get $addr))',
           wtype: :I32
  end

  def self.load32_16(addr)
    arg addr: :I32
    result :I32
    inline wat: '(i32.load16_u (local.get $addr))',
           wtype: :I32
  end

  def self.load32(addr)
    arg addr: :I32
    result :I32
    inline wat: '(i32.load (local.get $addr))',
           wtype: :I32
  end

  def self.load64_8(addr)
    arg addr: :I32
    result :I64
    inline wat: '(i64.load8_u (local.get $addr))',
           wtype: :I64
  end

  def self.load64_16(addr)
    arg addr: :I32
    result :I64
    inline wat: '(i64.load16_u (local.get $addr))',
           wtype: :I64
  end
  def self.load64_32(addr)
    arg addr: :I32
    result :I64
    inline wat: '(i64.load32_u (local.get $addr))',
           wtype: :I64
  end
  def self.load64(addr)
    arg addr: :I32
    result :I64
    inline wat: '(i64.load (local.get $addr))',
           wtype: :I64
  end

  def self.store32_8(addr, value)
    arg addr: :I32, value: :I32
    result :none
    inline wat: '(i32.store8 (local.get $addr) (local.get $value))',
           wtype: :none
  end

  def self.store32_16(addr, value)
    arg addr: :I32, value: :I32
    result :none
    inline wat: '(i32.store16 (local.get $addr) (local.get $value))',
           wtype: :none
  end

  def self.store32(addr, value)
    arg addr: :I32, value: :I32
    result :none
    inline wat: '(i32.store (local.get $addr) (local.get $value))',
           wtype: :none
  end

  def self.store64_8(addr, value)
    arg addr: :I32, value: :I64
    result :none
    inline wat: '(i64.store8 (local.get $addr) (local.get $value))',
           wtype: :none
  end

  def self.store64_16(addr, value)
    arg addr: :I32, value: :I64
    result :none
    inline wat: '(i64.store16 (local.get $addr) (local.get $value))',
           wtype: :none
  end

  def self.store64_32(addr, value)
    arg addr: :I32, value: :I64
    result :none
    inline wat: '(i64.store32 (local.get $addr) (local.get $value))',
           wtype: :none
  end

  def self.store64(addr, value)
    arg addr: :I32, value: :I64
    result :none
    inline wat: '(i64.store (local.get $addr) (local.get $value))',
           wtype: :none
  end
end