# Rubinius WebAssembly VM
# Copyright (c) 2019-2020, Laurent Julliard and contributors
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
    bytes = File.read(@builder.target)
    @instance = Wasmer::Instance.new(bytes)
    @exports = @instance.exports
  end

  def test_initial_memory_size
    assert_equal @@initial_page_count, @exports.memory_c_size
  end

  def test_grow_zero_page
    assert_equal @@initial_page_count, @exports.memory_c_grow(0)
    assert_equal @@initial_page_count, @exports.memory_c_size
  end

  def test_grow_one_page
    assert_equal @@initial_page_count, @exports.memory_c_grow(1)
    assert_equal @@initial_page_count+1, @exports.memory_c_size
  end

  def test_grow_ten_pages
    assert_equal @@initial_page_count, @exports.memory_c_grow(10)
    assert_equal @@initial_page_count+10, @exports.memory_c_size
  end

  def test_grow_five_pages_twice
    assert_equal @@initial_page_count, @exports.memory_c_grow(5)
    assert_equal @@initial_page_count+5, @exports.memory_c_size
    assert_equal @@initial_page_count+5, @exports.memory_c_grow(5)
    assert_equal @@initial_page_count+10, @exports.memory_c_size
  end
end