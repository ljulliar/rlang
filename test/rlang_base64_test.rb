# Rubinius WebAssembly VM
# Copyright (c) 2019-2020, Laurent Julliard and contributors
# All rights reserved.

require 'test_helper'
require 'wasmer'
require_relative '../lib/builder'
require_relative '../lib/ruby/mirror/rstring.rb'
require 'base64'


class RlangBase64Test < Minitest::Test

  TEST_FILES_DIR = File.expand_path('../rlang_base64_files', __FILE__)
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

  # test encoding methods
  def test_base64_encode_1char
    assert_equal Base64.encode64("A"), RString.new(@instance, @exports.send(@wfunc).call) # Encodes "A"
  end

  def test_base64_encode_2chars
    assert_equal Base64.encode64("AB"), RString.new(@instance, @exports.send(@wfunc).call) # Encodes "A"
  end

  def test_base64_encode_3chars
    assert_equal Base64.encode64("ABC"), RString.new(@instance, @exports.send(@wfunc).call) # Encodes "A"
  end

  def test_base64_encode_manychars
    source_string = String.new("\0\1\2\3" * 34, encoding: 'ASCII-8BIT')
    assert_equal Base64.encode64(source_string), RString.new(@instance, @exports.send(@wfunc).call)
  end

  def test_base64_strict_encode_manychars
    source_string = String.new("\0\1\2\3" * 34, encoding: 'ASCII-8BIT')
    assert_equal Base64.strict_encode64(source_string), RString.new(@instance, @exports.send(@wfunc).call)
  end

  def test_base64_urlsafe_encode_manychars
    source_string = String.new("\0\1\2\3\100\127\88\85" * 34, encoding: 'ASCII-8BIT')
    assert_equal Base64.urlsafe_encode64(source_string), RString.new(@instance, @exports.send(@wfunc).call)
  end

  # test decoding methods
  def test_base64_decode_1char
    assert_equal "A", RString.new(@instance, @exports.send(@wfunc).call) # Encodes "A"
  end

  def test_base64_decode_2chars
    assert_equal "AB", RString.new(@instance, @exports.send(@wfunc).call) # Encodes "A"
  end

  def test_base64_decode_3chars
    assert_equal "ABC", RString.new(@instance, @exports.send(@wfunc).call) # Encodes "A"
  end

  def test_base64_decode_manychars
    source_string = "\t\r\0\n"*20
    assert_equal source_string, RString.new(@instance, @exports.send(@wfunc).call)
  end

  def test_base64_strict_decode_manychars
    source_string = String.new("\t\r\0\0", encoding: 'ASCII-8BIT') * 20
    assert_equal source_string, RString.new(@instance, @exports.send(@wfunc).call)
  end
  
  def test_base64_urlsafe_decode_manychars
    source_string = String.new("\x00\x10\x83\xFB\xEF\xBE\x00\x10\x83\xFF\xFF\xFF\x00",
                               encoding: 'ASCII-8BIT')
    assert_equal source_string, RString.new(@instance, @exports.send(@wfunc).call)
  end

end