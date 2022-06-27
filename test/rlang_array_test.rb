# Rlang language, compiler and libraries
# Copyright (c) 2019-2022, Laurent Julliard and contributors
# All rights reserved.

require 'test_helper'
require 'wasmer'
require_relative '../lib/builder'


class RlangArrayTest < Minitest::Test

  TEST_FILES_DIR = File.expand_path('../rlang_array_files', __FILE__)
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

  def test_array32_dynamic_init
    assert_equal 2220, @instance.exports.send(@wfunc).call
  end

  def test_array32_static_init
    assert_equal 32385, @instance.exports.send(@wfunc).call
  end

  def test_array32_size
    100.times do
      sz = rand(255) + 1
      assert_equal 0, @instance.exports.send(@wfunc).call(sz)
    end
  end

  def test_array32_set
    array_obj_addr = @instance.exports.send(@wfunc).call
    # For the 32bit memory view port divide address by 4
    mem32 = @instance.exports.memory.uint32_view array_obj_addr/4

    assert_equal 100, mem32[0] # array length
    array_ptr = mem32[1] # pointer to first array_elements
    mem8 = @instance.exports.memory.uint32_view array_ptr/4

    # For the 32bit memory view port divide address by 4
    array = @instance.exports.memory.uint32_view array_ptr/4
    0.upto(99) do |idx|
      assert_equal idx*2, array[idx]
    end
  end

  def test_array32_get
    multiplier = 5
    array_obj_addr = @instance.exports.test_c_test_array32_set.call(multiplier)

    0.upto(99) do |idx|
      assert_equal multiplier * idx, @instance.exports.test_c_test_array32_get.call(idx)
    end
  end

  def test_array32_get_negative_index
    multiplier = 5
    array_obj_addr = @instance.exports.test_c_test_array32_set.call(multiplier)

    1.upto(100) do |idx|
      assert_equal multiplier * (100-idx), @instance.exports.test_c_test_array32_get.call(idx)
    end
  end

  def test_array64_get
    # Initialize and set up the array
    @instance.exports.test_c_test_array64_set.call
    # Test each array element
    0.upto(19) do |idx|
      assert @instance.exports.test_c_test_array64_get.call(idx)
    end
  end

end