# Rubinius WebAssembly VM
# Copyright (c) 2019-2020, Laurent Julliard and contributors
# All rights reserved.

require 'test_helper'
require 'wasmer'
require_relative '../lib/builder'


class RlangStringTest < Minitest::Test

  TEST_FILES_DIR = File.expand_path('../rlang_string_files', __FILE__)
  RLANG_DIR = File.expand_path('../../lib', __FILE__)

  # Rlang compilation options by method
  @@load_path_options = {}

  @@initial_page_count = 4
  $-w = false

  def setup
    # Name of wasm test method to call
    @wfunc = "test_c_#{self.name}"
    # Compile rlang test file to WASM bytecode
    test_file = File.join(TEST_FILES_DIR,"#{self.name}.rb")

    # Setup parser/compiler options
    options = {}
    options[:LOAD_PATH] = @@load_path_options[self.name.to_sym] || []
    options[:__FILE__] = test_file
    options[:export_all] = true
    options[:memory_min] = @@initial_page_count
    options[:log_level] = 'FATAL'

    # Compile Wat file to WASM bytecode
    @builder = Builder::Rlang::Builder.new(test_file, nil, options)
    unless @builder.compile
      raise "Error compiling #{test_file} to #{@builder.target}"
    end

    # Instantiate wasmer runtime
    bytes = File.read(@builder.target)
    @instance = Wasmer::Instance.new(bytes)
    @exports = @instance.exports
  end

  def test_string_dynamic_init
    stg = "A first string."
    length = stg.length
    stg_obj_addr = @instance.exports.send(@wfunc)
    # For the 32bit memory view port divide address by 4
    mem32 = @instance.memory.uint32_view stg_obj_addr/4

    assert_equal stg.length, mem32[0] # string length
    stg_ptr = mem32[1] # pointer to string literal

    mem8 = @instance.memory.uint8_view stg_ptr
    rlang_stg = (0..length-1).collect {|nth| mem8[0+nth].chr}.join('')
    assert_equal stg, rlang_stg
  end

  def test_string_static_init
    assert_equal 14042, @instance.exports.send(@wfunc)
  end

  def test_string_concat
    stg = "A first string." + " And a second one"
    length = stg.length
    stg_obj_addr = @instance.exports.send(@wfunc)

    # For the 32bit memory view port divide address by 4
    assert_equal length, @instance.exports.string_i_length(stg_obj_addr)

    stg_ptr = @instance.exports.string_i_ptr(stg_obj_addr)
    mem8 = @instance.memory.uint8_view stg_ptr
    rlang_stg = (0..length-1).collect {|nth| mem8[0+nth].chr}.join('')
    assert_equal stg, rlang_stg
  end
end