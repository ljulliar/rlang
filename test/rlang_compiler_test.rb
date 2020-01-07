# Rubinius WebAssembly VM
# Copyright (c) 2019-2020, Laurent Julliard and contributors
# All rights reserved.
require 'tempfile'
require 'test_helper'

class RlangCompilerTest < Minitest::Test

  TEST_FILES_DIR = File.expand_path('../rlang_files', __FILE__)
  TEST_FILE = File.join(TEST_FILES_DIR, 'test_def_one_arg.rb')
  LIB_DIR = File.expand_path('../../lib', __FILE__)
  RLANG = File.expand_path('../../bin/rlang', __FILE__)

  def setup
    @tf_path = "/tmp/test_#{$$}"
  end

  def teardown
    File.unlink(@tf_path)
  end

  def test_rlang_ast
    assert system("ruby -I #{LIB_DIR} #{RLANG} --ast #{TEST_FILE} > /dev/null")
    assert system("ruby -I #{LIB_DIR} #{RLANG} --ast #{TEST_FILE} -o #{@tf_path}")
    assert File.exist?(@tf_path)
    assert File.size(@tf_path) > 0
  end

  def test_rlang_wat
    assert system("ruby -I #{LIB_DIR} #{RLANG} --wat #{TEST_FILE} > /dev/null")
    assert system("ruby -I#{LIB_DIR} -- #{RLANG} --wat #{TEST_FILE} -o #{@tf_path}")
    assert File.exist?(@tf_path)
    assert File.size(@tf_path) > 0
  end

  def test_rlang_wasm
    assert system("ruby -I#{LIB_DIR} -- #{RLANG} --wasm #{TEST_FILE} > /dev/null")
    assert system("ruby -I#{LIB_DIR} -- #{RLANG} --wasm #{TEST_FILE} -o #{@tf_path}")
    assert File.exist?(@tf_path)
    assert File.size(@tf_path) > 0
  end
end
