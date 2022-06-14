# Rubinius WebAssembly VM
# Copyright (c) 2019-2020, Laurent Julliard and contributors
# All rights reserved.

require 'test_helper'
require 'wasmer'
require_relative '../lib/builder'
require_relative '../lib/ruby/mirror/rstring.rb'


class RlangStringTest < Minitest::Test

  TEST_FILES_DIR = File.expand_path('../rlang_string_files', __FILE__)
  RLANG_DIR = File.expand_path('../../lib/rlang/lib', __FILE__)

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
    options[:LOAD_PATH] = [RLANG_DIR] + (@@load_path_options[self.name.to_sym] || [])
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
    # Let's define the store, that holds the engine, that holds the compiler.
    store = Wasmer::Store.new
    # Let's compile the module to be able to execute it!
    module_ = Wasmer::Module.new store, IO.read(@builder.target, mode: "rb")
    # Now the module is compiled, we can instantiate it.
    @instance = Wasmer::Instance.new module_, nil
    @exports = @instance.exports
  end

  def test_string_dynamic_init
    stg = "A first string."
    length = stg.length
    stg_obj_addr = @exports.send(@wfunc).call
    # For the 32bit memory view port divide address by 4
    mem32 = @exports.memory.uint32_view stg_obj_addr/4

    assert_equal stg.length, mem32[0] # string length
    stg_ptr = mem32[1] # pointer to string literal

    mem8 = @exports.memory.uint8_view stg_ptr
    rlang_stg = (0..length-1).collect {|nth| mem8[0+nth].chr}.join('')
    assert_equal stg, rlang_stg
  end

  def test_string_static_init
    assert_equal 14042, @exports.send(@wfunc).call
  end

  def test_string_concat
    stg = "A first string." + " And a second one"
    length = stg.length
    stg_obj_addr = @exports.send(@wfunc).call

    # For the 32bit memory view port divide address by 4
    assert_equal length, @exports.string_i_length.call(stg_obj_addr)

    stg_ptr = @exports.string_i_ptr.call(stg_obj_addr)
    mem8 = @exports.memory.uint8_view stg_ptr
    rlang_stg = (0..length-1).collect {|nth| mem8[0+nth].chr}.join('')
    assert_equal stg, rlang_stg
  end

  def test_string_index
    stg = "azerty"

    # Index 0 to last
    0.upto(stg.length-1) do |idx|
      stg_obj_addr = @exports.send(@wfunc).call(idx)
      stg_ptr = @exports.string_i_ptr.call(stg_obj_addr)
      mem8 = @exports.memory.uint8_view stg_ptr
      assert_equal stg[idx].ord,mem8[0], "Idx: #{idx}, Expected #{stg[idx].ord} got #{mem8[idx]}"
    end

    # Index 3 again with the Ruby string conversion
    # this to test the RString mirror class
    idx = 3
    stg_obj_addr = @exports.send(@wfunc).call(idx)
    ruby_stg = RString.new(@instance, stg_obj_addr)
    assert_equal stg[idx], ruby_stg, "Idx: #{idx}, Expected\"a\" got #{ruby_stg}"


    # Index beyond last retuns an empty string
    idx = stg.length
    stg_obj_addr = @exports.send(@wfunc).call(idx)
    stg_length = @exports.string_i_length.call(stg_obj_addr)
    assert_equal 0, stg_length
  end

  def test_string_index_assign
    expected_stg = "AZeRT123"
    stg_obj_addr = @exports.send(@wfunc).call
    ruby_stg = RString.new(@instance, stg_obj_addr)
    assert_equal expected_stg, ruby_stg
  end

  def test_string_index_assign_long_string
    expected_stg = Array.new(256) {|i| i}.map(&:chr).join('')
    assert_equal 256, expected_stg.length

    stg_obj_addr = @exports.send(@wfunc).call
    ruby_stg = RString.new(@instance, stg_obj_addr)
    assert_equal expected_stg, ruby_stg
  end

  def test_string_ord_A
    assert_equal 65, @exports.send(@wfunc).call
  end

  def test_string_times_init
    assert_equal ("ABCD" * 35).encode!(Encoding::US_ASCII), RString.new(@instance, @exports.send(@wfunc).call)
  end

  def test_string_equal
    assert true, @exports.send(@wfunc).call
  end

  def test_string_equal_not
    assert true, @exports.send(@wfunc).call
  end

  def test_string_equal_not_op
    assert true, @exports.send(@wfunc).call
  end

end