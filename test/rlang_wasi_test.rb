# Rlang language, compiler and libraries
# Copyright (c) 2019-2022, Laurent Julliard and contributors
# All rights reserved.

require 'test_helper'
require 'wasmer'
require_relative '../lib/builder'


class RlangWasiTest < Minitest::Test

  TEST_FILES_DIR = File.expand_path('../rlang_wasi_files', __FILE__)
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

    # Prepare instantiation of wasmer runtime
    # Let's define the store, that holds the engine, that holds the compiler.
    @store = Wasmer::Store.new
    # Let's compile the module to be able to execute it!
    @module_ = Wasmer::Module.new @store, IO.read(@builder.target, mode: "rb")
    # We need to know what WASI version the runtime is using
    @wasi_version = Wasmer::Wasi::get_version @module_, true

  end

  def finish_runtime_instantiation
    # Build proper WASI version module to import when instantiating the
    # WASM runtime
    @import_object = @wasi_env.generate_import_object @store, @wasi_version
    # Now the module can be instantiated
    @instance = Wasmer::Instance.new @module_, @import_object
    @exports = @instance.exports
  end

  def test_env_count
    # Initialize the WASI environment
    @wasi_env = Wasmer::Wasi::StateBuilder.new(@wfunc)
    .environment('COLOR', 'true')
    .environment('LOG', 'false')
    .environment('VERBOSE', 'false')
    .finalize
    self.finish_runtime_instantiation

    # We set up 3 environment variables in the environment
    assert_equal 3, @exports.send(@wfunc).call
  end

  def test_arg_count
    # Initialize the WASI environment
    @wasi_env = Wasmer::Wasi::StateBuilder.new(@wfunc)
    .argument('--test1')
    .argument('--test2')
    .finalize
    self.finish_runtime_instantiation

    # Build proper WASI version module to import when instantiating the
    # WASM runtime
    @import_object = @wasi_env.generate_import_object @store, @wasi_version
    # Now the module is compiled, we can instantiate it.
    @instance = Wasmer::Instance.new @module_, @import_object

    # We placed 2 arguments in the environment --test1 and --test2
    # plus one argument for the script name
    assert_equal 1+2, @exports.send(@wfunc).call
  end

end