# Rlang language, compiler and libraries
# Copyright (c) 2019-2022, Laurent Julliard and contributors
# All rights reserved.

require 'test_helper'
require 'wasmer'
require_relative '../lib/builder'


class RlangMemoryTest < Minitest::Test

  TEST_FILES_DIR = File.expand_path('../rlang_memory_files', __FILE__)
  RLANG_DIR = File.expand_path('../../lib/rlang/lib', __FILE__)

  # Rlang compilation options by method
  @@load_path_options = {}

  @@initial_page_count = 4

  def setup
    # Compile rlang test file to WASM bytecode
    test_file = File.join(TEST_FILES_DIR,"test_memory.rb")

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

  def test_initial_memory_size
    assert_equal @@initial_page_count, @exports.memory_c_size.call
  end

  def test_grow_zero_page
    assert_equal @@initial_page_count, @exports.memory_c_grow.call(0)
    assert_equal @@initial_page_count, @exports.memory_c_size.call
  end

  def test_grow_one_page
    assert_equal @@initial_page_count, @exports.memory_c_grow.call(1)
    assert_equal @@initial_page_count+1, @exports.memory_c_size.call
  end

  def test_grow_ten_pages
    assert_equal @@initial_page_count, @exports.memory_c_grow.call(10)
    assert_equal @@initial_page_count+10, @exports.memory_c_size.call
  end

  def test_grow_five_pages_twice
    assert_equal @@initial_page_count, @exports.memory_c_grow.call(5)
    assert_equal @@initial_page_count+5, @exports.memory_c_size.call
    assert_equal @@initial_page_count+5, @exports.memory_c_grow.call(5)
    assert_equal @@initial_page_count+10, @exports.memory_c_size.call
  end
end