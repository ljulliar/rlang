# Rubinius WebAssembly VM
# Copyright (c) 2019-2020, Laurent Julliard and contributors
# All rights reserved.

require 'test_helper'
require 'wasmer'
require_relative '../lib/builder'


class RlangTest < Minitest::Test

  TEST_FILES_DIR = File.expand_path('../rlang_test_files', __FILE__)
  RLANG_DIR = File.expand_path('../../lib', __FILE__)

  # Rlang compilation options by method
  # add "-v debug" to debug a test method
  @@rlang_options = {
    test_require: "-I#{TEST_FILES_DIR}",
    test_require_embedded: "-I#{TEST_FILES_DIR}",
    test_require_twice: "-I#{TEST_FILES_DIR}",
    test_require_relative: "",
    test_require_wat: "-I#{TEST_FILES_DIR}",
    test_require_wat_with_extension: "-I#{TEST_FILES_DIR}",
    test_require_with_extension: "-I#{TEST_FILES_DIR}",
    test_rlanglib_memory: "-I#{RLANG_DIR}",
  }

  def setup
    # Name of wasm test method to call
    @wfunc = "test_c_#{self.name}"
    # Compile rlang test file to WASM bytecode
    test_file = File.join(TEST_FILES_DIR,"#{self.name}.rb")
    @builder = Builder::Rlang::Builder.new()
    target = Tempfile.new([self.name, '.wat'])
    target.persist!
    assert @builder.compile(test_file, target.path, @@rlang_options[self.name.to_sym])
    # Instantiate a wasmer runtime
    bytes = File.read(@builder.target)
    @instance = Wasmer::Instance.new(bytes)
  end

  def teardown
    @builder.cleanup
  end

  def test_bool_and
    assert_equal 1, @instance.exports.send(@wfunc, 11, 99)
    assert_equal 0, @instance.exports.send(@wfunc, 8, 50)
    assert_equal 0, @instance.exports.send(@wfunc, 11, 101)
    assert_equal 0, @instance.exports.send(@wfunc, 8, 101)
  end

  def test_bool_false
    assert_equal 10101, @instance.exports.send(@wfunc)
  end

  def test_bool_or
    assert_equal 1, @instance.exports.send(@wfunc, 11, 99)
    assert_equal 1, @instance.exports.send(@wfunc, 8, 50)
    assert_equal 1, @instance.exports.send(@wfunc, 11, 101)
    assert_equal 0, @instance.exports.send(@wfunc, 8, 101)
  end

  def test_bool_not
    assert_equal 0, @instance.exports.send(@wfunc, 10)
    assert_equal 1, @instance.exports.send(@wfunc, 11)
  end

  def test_bool_true
    assert_equal 10101, @instance.exports.send(@wfunc)
  end

  def test_call_add_i64_func
    assert_equal 20, @instance.exports.send(@wfunc)
  end
  
  def test_call_class_method
    assert_equal 5200, @instance.exports.send(@wfunc, 500)
  end

  def test_call_instance_method
    assert_equal 1070503, @instance.exports.send(@wfunc, 6)
  end

  def test_call_method_recursive
    assert_equal 28657, @instance.exports.send(@wfunc, 23)
  end

  def test_call_on_self_class
    assert_equal 5020, @instance.exports.send(@wfunc)
  end

  def test_call_on_self_instance
    assert_equal 5020, @instance.exports.send(@wfunc)
  end

  def test_call_other_class_method_and_add
    assert_equal 140, @instance.exports.send(@wfunc, 100)
  end

  def test_call_other_class_method
    assert_equal 25, @instance.exports.send(@wfunc, 10)
  end

  def test_cast_i32_to_i64_signed
    assert_equal 3, @instance.exports.send(@wfunc)
  end

  def test_cast_i32_to_i64_unsigned
    assert_equal 3, @instance.exports.send(@wfunc)
  end

  def test_cast_i32_to_i64
    assert_equal 5, @instance.exports.send(@wfunc)
  end

  def test_class_var_set_in_class
    assert_equal 200, @instance.exports.send(@wfunc)
  end

  def test_class_var_set_in_method
    assert_equal 200, @instance.exports.send(@wfunc)
  end

  def test_constant_in_class
    assert_equal 51, @instance.exports.send(@wfunc)
  end
  
  def test_constant_in_other_class
    assert_equal 1001, @instance.exports.send(@wfunc)
  end

  def test_data_init
    mem8 = @instance.memory.uint8_view 0
    mem32 = @instance.memory.uint32_view 0

    stg = (0..15).collect {|nth| mem8[0+nth].chr}.join('')
    assert_equal "My\tLittle\tRlang\x00", stg

    int64 = (0..7).collect {|nth| mem8[16+nth].chr}.join('').unpack('Q<').first
    assert_equal 32_000_000_000, int64

    assert_equal 32000, mem32[24/4]
    assert_equal 0, mem32[28/4] # Address of the 1st string
    assert_equal 16, mem32[32/4] # Address of the above i64
    assert_equal 5, mem32[36/4]
    assert_equal 257, mem32[40/4]

    stg = (0..8).collect {|nth| mem8[44+nth].chr}.join('')
    assert_equal "A string\n", stg
  end

  def test_def_no_arg_return_3
    assert_equal 3, @instance.exports.send(@wfunc)
  end

  def test_def_no_result_returned
    assert_nil @instance.exports.send(@wfunc)
  end

  def test_def_one_arg_with_type_and_implicit_type_cast
    assert_equal 1000, @instance.exports.send(@wfunc, 100)
  end
  
  def test_def_one_arg
    assert_equal 50, @instance.exports.send(@wfunc, 10)
  end

  def test_def_result_type_declaration
    assert_equal 121, @instance.exports.send(@wfunc)
  end
  
  def test_def_return_i64
    assert_equal 21, @instance.exports.send(@wfunc)
  end

  def test_def_return_no_value_OK
    assert_nil @instance.exports.send(@wfunc)
  end

  def test_def_two_args
    assert_equal 200, @instance.exports.send(@wfunc, 10, 100)
  end
  
  def test_global_var_init_i64
    assert_equal 400_000_000_000, @instance.exports.send(@wfunc)
  end
  
  def test_global_var_init
    assert_equal 2, @instance.exports.send(@wfunc)
  end
  
  def test_global_var_set
    assert_equal 0, @instance.exports.send(@wfunc)
  end
  
  def test_if_else_false_with_type_i64
    assert_equal 20, @instance.exports.send(@wfunc)
  end
  
  def test_if_else_false
    assert_equal 20, @instance.exports.send(@wfunc)
  end
  
  def test_if_else_true
    assert_equal 100, @instance.exports.send(@wfunc)
  end
  
  def test_if_elsif_else
    assert_equal 1, @instance.exports.send(@wfunc, 9)
    assert_equal 2, @instance.exports.send(@wfunc, 39)
    assert_equal 3, @instance.exports.send(@wfunc, 599)
    assert_equal 0, @instance.exports.send(@wfunc, 2000)
  end

  def test_if_false
    assert_equal 20, @instance.exports.send(@wfunc)
  end
  
  def test_if_modifier
    assert_equal 14, @instance.exports.send(@wfunc, 7)
    assert_equal 4, @instance.exports.send(@wfunc, 4)
  end

  def test_if_true
    assert_equal 30, @instance.exports.send(@wfunc)
  end

  def test_inline
    assert_equal 2500, @instance.exports.send(@wfunc, 5)
  end

  def test_inline_with_wtype
    assert_equal 40_000_000_000, @instance.exports.send(@wfunc, 20000)
  end

  def test_local_var_chained_asgn
    assert_equal 555, @instance.exports.send(@wfunc)
  end 

  def test_local_var_set
    assert_equal 1000, @instance.exports.send(@wfunc)
  end    

  def test_loop_break
    assert_equal 5, @instance.exports.send(@wfunc)
  end    

  def test_loop_next
    assert_equal 789, @instance.exports.send(@wfunc)
  end

  def test_loop_unless_else_false
    assert_equal 10, @instance.exports.send(@wfunc)
  end    

  def test_loop_unless_modifier
    assert_equal 6, @instance.exports.send(@wfunc, 3)
    assert_equal 10, @instance.exports.send(@wfunc, 10)
  end    

  def test_loop_until
    assert_equal 10, @instance.exports.send(@wfunc)
  end    

  def test_loop_while
    assert_equal 0, @instance.exports.send(@wfunc)
  end    

  def test_multiple_expressions
    assert_equal 32, @instance.exports.send(@wfunc)
  end    

  def test_object_pointer_add
    assert_equal 56, @instance.exports.send(@wfunc)
  end  

  def test_object_pointer_substract
    assert_equal 28, @instance.exports.send(@wfunc)
  end

  def test_object_pointer_compare
    assert_equal 1+4+128+256+512+2048+8192, @instance.exports.send(@wfunc)
  end

  def test_opasgn_class_var
    assert_equal 900, @instance.exports.send(@wfunc)
  end    

  def test_opasgn_embedded
    assert_equal 32, @instance.exports.send(@wfunc, 10)
  end    

  def test_opasgn_global_var
    assert_equal 1, @instance.exports.send(@wfunc)
  end    

  def test_opasgn_local_var
    assert_equal 400, @instance.exports.send(@wfunc, 20)
  end

  def test_opasgn_setter
    assert_equal 98, @instance.exports.send(@wfunc, 100)
  end

  def test_operator_on_object
    base = @instance.exports.test_c_base
    assert_equal 12*5, @instance.exports.send(@wfunc) - base
  end

  def test_operator_precedence
    assert_equal 70304, @instance.exports.send(@wfunc)
  end

  def test_require
    assert_equal 200, @instance.exports.send(@wfunc)
  end

  def test_require_embedded
    assert_equal 200, @instance.exports.send(@wfunc)
  end

  def test_require_twice
    assert_equal 200, @instance.exports.send(@wfunc)
  end

  def test_require_relative
    assert_equal 200, @instance.exports.send(@wfunc)
  end

  def test_require_wat
    assert_equal 1001, @instance.exports.send(@wfunc)
  end

  def test_require_wat_with_extension
    assert_equal 1001, @instance.exports.send(@wfunc)
  end

  def test_require_with_extension
    assert_equal 200, @instance.exports.send(@wfunc)
  end

  def test_rlanglib_memory
    # Return current memory size
    assert_equal 4, @instance.exports.send(@wfunc, 0)
    # grow memory size by 2 pages
    assert_equal 4, @instance.exports.send(@wfunc, 2)
    assert_equal 6, @instance.exports.send(@wfunc, 0)
  end

  def test_wattr_class_size
    assert_equal 28, @instance.exports.send(@wfunc)
  end

  def test_wattr_definition
    assert_equal 10004, @instance.exports.send(@wfunc, 5)
  end

  def test_wattr_definition_with_type
    assert_equal 1_000_000_000_000, @instance.exports.send(@wfunc, 1_000_000)
  end
end
