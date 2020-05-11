require 'rlang_core'
require_relative './cube'

class Test

  # Allocate some amount of static memory
  @@cvar1 = Cube.new
  @@cvar2 = Cube.new
  @@cvar3 = Cube.new

  export
  def self.test_object_pointer_compare
    local c: :Cube, oc: :Cube, yaoc: :Cube

    c = @@cvar3
    oc = c + 10
    yaoc = c - 2

    x = 0
    # Only 1, 4 should work
    x |= 1 if oc > c
    x |= 2 if oc < c
    x |= 4 if oc >= c
    x |= 8 if oc <= c
    x |= 16 if oc == c

    # Only 128, 256, 512 should work
    x |= 32 if c > @@cvar3
    x |= 64 if c < @@cvar3
    x |= 128 if c >= @@cvar3
    x |= 256 if c <= @@cvar3
    x |= 512 if c == @@cvar3

    # Only 2048, 8192 should work
    x |= 1024 if yaoc > @@cvar3
    x |= 2048 if yaoc < @@cvar3
    x |= 4096 if yaoc >= @@cvar3
    x |= 8192 if yaoc <= @@cvar3
    x |= 16384 if yaoc == @@cvar3

    # expected result
    # 1+4+128+256+512+2048+8192
    x
  end
end