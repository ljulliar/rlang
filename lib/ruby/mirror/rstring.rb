# Rlang WebAssembly compiler
# Copyright (c) 2019-2022, Laurent Julliard and contributors
# All rights reserved.

require 'wasmer'

class RString < String
  # Turn a Rlang String object into a Ruby String mirror object
  def initialize(wasm_instance, rlang_obj_addr)
    stg_ptr = wasm_instance.exports.string_i_ptr.call(rlang_obj_addr)
    stg_length = wasm_instance.exports.string_i_length.call(rlang_obj_addr)
    mem8 = wasm_instance.exports.memory.uint8_view stg_ptr
    ruby_stg = 0.upto(stg_length-1).collect {|i| mem8[i].chr}.join('')
    super(ruby_stg)
  end
end