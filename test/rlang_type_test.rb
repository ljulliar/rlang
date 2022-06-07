# Rlang Webassembly compiler
# Copyright (c) 2019-2020, Laurent Julliard and contributors
# All rights reserved.

require 'test_helper'
require 'wasmer'
require_relative '../lib/builder'
require_relative '../lib/ruby/mirror/rstring.rb'


class RlangTypeTest < Minitest::Test

  TEST_FILES_DIR = File.expand_path('../rlang_type_files', __FILE__)
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

  def test_i32_to_s
    assert_equal "1000", RString.new(@instance, @exports.send(@wfunc).call(1000))
    assert_equal "0", RString.new(@instance, @exports.send(@wfunc).call(0))
  end

  def test_i32_chr
    assert_equal "A", RString.new(@instance, @exports.send(@wfunc).call(65))
    assert_equal "$", RString.new(@instance, @exports.send(@wfunc).call(36))
    assert_equal "\n", RString.new(@instance, @exports.send(@wfunc).call(10))
  end

end