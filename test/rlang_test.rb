# Rlang language, compiler and libraries
# Copyright (c) 2019-2022, Laurent Julliard and contributors
# All rights reserved.

require 'test_helper'
require 'wasmer'
require_relative '../lib/builder'

# Prevent emitting warnings about toot
# many argument in sprintf
$-w = false

class RlangTest < Minitest::Test

  TEST_FILES_DIR = File.expand_path('../rlang_test_files', __FILE__)
  RLANG_DIR = File.expand_path('../../lib/rlang/lib', __FILE__)

  # Rlang compilation options by method
  @@load_path_options = {
    test_require: [TEST_FILES_DIR],
    test_require_embedded: [TEST_FILES_DIR],
    test_require_twice: [TEST_FILES_DIR],
    test_require_wat: [TEST_FILES_DIR],
    test_require_wat_with_extension: [TEST_FILES_DIR],
    test_require_with_extension: [TEST_FILES_DIR]
  }

  def setup
    # Name of wasm test method to call
    @wfunc = "test_c_#{self.name}"
    test_file = File.join(TEST_FILES_DIR,"#{self.name}.rb")

    # Setup parser/compiler options
    options = {}
    options[:LOAD_PATH] = [RLANG_DIR] + (@@load_path_options[self.name.to_sym] || [])
    options[:__FILE__] = test_file
    options[:export_all] = true
    options[:memory_min] = 1
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
  end

  def teardown
    #@builder.cleanup
  end

  def test_bool_and
    assert_equal 1, @instance.exports.send(@wfunc).call(11, 99)
    assert_equal 0, @instance.exports.send(@wfunc).call(8, 50)
    assert_equal 0, @instance.exports.send(@wfunc).call(11, 101)
    assert_equal 0, @instance.exports.send(@wfunc).call(8, 101)
  end

  def test_bool_false
    assert_equal 10101, @instance.exports.send(@wfunc).call
  end

  def test_bool_or
    assert_equal 1, @instance.exports.send(@wfunc).call(11, 99)
    assert_equal 1, @instance.exports.send(@wfunc).call(8, 50)
    assert_equal 1, @instance.exports.send(@wfunc).call(11, 101)
    assert_equal 0, @instance.exports.send(@wfunc).call(8, 101)
  end

  def test_bool_not
    assert_equal 0, @instance.exports.send(@wfunc).call(10)
    assert_equal 1, @instance.exports.send(@wfunc).call(11)
  end

  def test_bool_true
    assert_equal 10101, @instance.exports.send(@wfunc).call
  end

  def test_call_add_i64_func
    assert_equal 20, @instance.exports.send(@wfunc).call
  end

  def test_call_add_f64_func
    assert_equal 1105000.0, @instance.exports.send(@wfunc).call
  end

  def test_call_add_f32_func
    assert_equal 1037500.0, @instance.exports.send(@wfunc).call
  end

  def test_compute_pi_f32
    assert_equal '3.141597', '%.6f' % @instance.exports.send(@wfunc).call
  end

  def test_compute_pi_f64
    assert_equal '3.14159265', '%.8f' %@instance.exports.send(@wfunc).call
  end
  
  def test_call_class_method
    assert_equal 5200, @instance.exports.send(@wfunc).call(500)
  end

  def test_call_instance_method
    assert_equal 1070503, @instance.exports.send(@wfunc).call(6)
  end

  def test_call_instance_method_on_const
    assert_equal 1070503, @instance.exports.send(@wfunc).call(6)
  end

  def test_call_instance_method_on_global
    assert_equal 1070503, @instance.exports.send(@wfunc).call(6)
  end

  def test_call_method_lookup
    assert_equal 64142, @instance.exports.test_c_test_call_method_lookup_with_modules.call
    assert_equal 76171, @instance.exports.test_c_test_call_method_lookup_with_superclasses.call
  end

  def test_call_method_recursive
    assert_equal 28657, @instance.exports.send(@wfunc).call(23)
  end

  def test_call_on_self_class
    assert_equal 5020, @instance.exports.send(@wfunc).call
  end

  def test_call_on_self_instance
    assert_equal 5020, @instance.exports.send(@wfunc).call
  end

  def test_call_other_class_method_and_add
    assert_equal 140, @instance.exports.send(@wfunc).call(100)
  end

  def test_call_other_class_method
    assert_equal 25, @instance.exports.send(@wfunc).call(10)
  end

  def test_cast_i32_to_i64_signed
    assert_equal 3, @instance.exports.send(@wfunc).call
  end

  def test_cast_i32_to_i64_unsigned
    assert_equal 3, @instance.exports.send(@wfunc).call
  end

  def test_cast_instance_var
    assert_equal 5, @instance.exports.send(@wfunc).call
  end

  def test_cast_implicit_i32_to_i64
    assert_equal 2147483658, @instance.exports.send(@wfunc).call
  end

  def test_cast_i32_to_i64
    assert_equal 5, @instance.exports.send(@wfunc).call
  end

  def test_cast_i32_to_f32
    # Should return -2147483612 but Wasmer runtime
    # returns -2147483648
    # TODO : see why wasmer does that
    assert_equal -2147483648, @instance.exports.send(@wfunc).call
  end
  
  def test_cast_i32_to_f64
    assert_equal -2147483612, @instance.exports.send(@wfunc).call
  end

  def test_cast_f32_to_i64
    # Should return 12345670000 but Wasmer runtime
    # returns 123456700416
    # TODO : see why wasmer does that
    assert_equal 123456700416, @instance.exports.send(@wfunc).call
  end

  def test_cast_f32_to_i32
    assert_equal -21474836, @instance.exports.send(@wfunc).call
  end

  def test_cast_f32_to_f64
    assert_equal 123456700416.0, @instance.exports.send(@wfunc).call
  end
  
  def test_cast_f64_to_i64
    # Should return 12345670000 but Wasmer runtime
    # returns 123456700416
    # TODO : see why wasmer does that
    assert_equal 1234567012345679, @instance.exports.send(@wfunc).call
  end

  def test_cast_f64_to_i32
    assert_equal -21474836, @instance.exports.send(@wfunc).call
  end

  def test_cast_f64_to_f32
    # Should return 123456790.0 but Wasmer runtime
    # returns 123456792.0
    # TODO : see why wasmer does that
    assert_equal 123456792.0, @instance.exports.send(@wfunc).call
  end
  def test_class_inheritance
    assert_equal 36, @instance.exports.send(@wfunc).call
  end

  def test_class_in_class
    assert_equal 1111, @instance.exports.send(@wfunc).call
  end

  def test_class_var_set_in_class
    assert_equal 200, @instance.exports.send(@wfunc).call
  end

  def test_class_var_set_in_method
    assert_equal 200, @instance.exports.send(@wfunc).call
  end

  def test_constant_init
    assert_equal 30500, @instance.exports.send(@wfunc).call
  end

  def test_constant_in_class
    assert_equal 51, @instance.exports.send(@wfunc).call
  end

  def test_constant_in_embedded_classes
    assert_equal 122, @instance.exports.send(@wfunc).call
  end

  def test_constant_in_inherited_classes
    assert_equal 122, @instance.exports.send(@wfunc).call
  end
   
  def test_constant_in_other_class
    assert_equal 1001, @instance.exports.send(@wfunc).call
  end

  def test_data_init
    base_address = address = 2048
    mem8 = @instance.exports.memory.uint8_view 0
    mem32 = @instance.exports.memory.uint32_view 0

    stg = (0..15).collect {|nth| mem8[address+nth].chr}.join('')
    assert_equal "My\tLittle\tRlang\x00", stg
    address += 16

    int64 = (0..7).collect {|nth| mem8[address+nth].chr}.join('').unpack('Q<').first
    assert_equal 32_000_000_000, int64
    int64_address = address
    address += 8

    assert_equal 32000, mem32[address/4]
    address += 4

    assert_equal base_address, mem32[address/4] # Address of the 1st string
    address += 4

    assert_equal int64_address, mem32[address/4] # Address of the above i64
    address += 4

    assert_equal 5, mem32[address/4]
    address += 4

    assert_equal 257, mem32[address/4]
    address += 4

    stg = (0..8).collect {|nth| mem8[address+nth].chr}.join('')
    assert_equal "A string\n", stg
  end

  def test_def_export
    assert_equal 10, @instance.exports.my_function_name.call
    assert_equal 100, @instance.exports.send(@wfunc).call
  end

  def test_def_no_arg_return_3
    assert_equal 3, @instance.exports.send(@wfunc).call
  end

  def test_def_no_result_returned
    assert_nil @instance.exports.send(@wfunc).call
  end

  def test_def_one_arg_with_type_and_implicit_type_cast
    assert_equal 1000, @instance.exports.send(@wfunc).call(100)
  end
  
  def test_def_one_arg
    assert_equal 50, @instance.exports.send(@wfunc).call(10)
  end

  def test_def_result_type_declaration
    assert_equal 121, @instance.exports.send(@wfunc).call
  end
  
  def test_def_return_i64
    assert_equal 21, @instance.exports.send(@wfunc).call
  end

  def test_def_return_no_value_OK
    assert_nil @instance.exports.send(@wfunc).call
  end

  def test_def_two_args
    assert_equal 200, @instance.exports.send(@wfunc).call(10, 100)
  end
  
  def test_global_var_init_i64
    assert_equal 400_000_000_000, @instance.exports.send(@wfunc).call
  end
    
  def test_global_var_init_f32
    # Compare the string representation to avoid
    # rounding problems
    assert_equal "3.14", '%.2f' % @instance.exports.send(@wfunc).call
  end
    
  def test_global_var_init_f64
    assert_equal 3.1234567891011e124, @instance.exports.send(@wfunc).call
  end

  def test_global_var_init
    assert_equal 3050700, @instance.exports.send(@wfunc).call
  end
  
  def test_global_var_init_twice
    assert_equal 2, @instance.exports.send(@wfunc).call
  end
  
  def test_global_var_set
    assert_equal 0, @instance.exports.send(@wfunc).call
  end
  
  def test_if_else_false_with_type_i64
    assert_equal 20, @instance.exports.send(@wfunc).call
  end
  
  def test_if_else_false
    assert_equal 20, @instance.exports.send(@wfunc).call
  end
  
  def test_if_else_true
    assert_equal 100, @instance.exports.send(@wfunc).call
  end
  
  def test_if_elsif_else
    assert_equal 1, @instance.exports.send(@wfunc).call(9)
    assert_equal 2, @instance.exports.send(@wfunc).call(39)
    assert_equal 3, @instance.exports.send(@wfunc).call(599)
    assert_equal 0, @instance.exports.send(@wfunc).call(2000)
  end

  def test_if_false
    assert_equal 20, @instance.exports.send(@wfunc).call
  end
  
  def test_if_modifier
    assert_equal 14, @instance.exports.send(@wfunc).call(7)
    assert_equal 4, @instance.exports.send(@wfunc).call(4)
  end

  def test_if_true
    assert_equal 30, @instance.exports.send(@wfunc).call
  end

  def test_inline
    assert_equal 2500, @instance.exports.send(@wfunc).call(5)
  end

  def test_inline_with_wtype
    assert_equal 40_000_000_000, @instance.exports.send(@wfunc).call(20000)
  end

  def test_instance_var_init
    assert_equal 100, @instance.exports.send(@wfunc).call
  end

  def test_local_var_chained_asgn
    assert_equal 555, @instance.exports.send(@wfunc).call
  end 

  def test_local_var_set
    assert_equal 1000, @instance.exports.send(@wfunc).call
  end    

  def test_loop_break
    assert_equal 5, @instance.exports.send(@wfunc).call
  end    

  def test_loop_next
    assert_equal 789, @instance.exports.send(@wfunc).call
  end

  def test_loop_unless_else_false
    assert_equal 10, @instance.exports.send(@wfunc).call
  end    

  def test_loop_unless_modifier
    assert_equal 6, @instance.exports.send(@wfunc).call(3)
    assert_equal 10, @instance.exports.send(@wfunc).call(10)
  end    

  def test_loop_until
    assert_equal 10, @instance.exports.send(@wfunc).call
  end    

  def test_loop_while
    assert_equal 0, @instance.exports.send(@wfunc).call
  end    

  def test_module_include
    assert_equal 1038, @instance.exports.send(@wfunc).call
  end

  def test_module_extend
    assert_equal 1038, @instance.exports.send(@wfunc).call
  end

  def test_multiple_expressions
    assert_equal 32, @instance.exports.send(@wfunc).call
  end    

  def test_object_pointer_add
    assert_equal 56, @instance.exports.send(@wfunc).call
  end  

  def test_object_pointer_substract
    assert_equal 28, @instance.exports.send(@wfunc).call
  end

  def test_object_pointer_compare
    assert_equal 1+4+128+256+512+2048+8192, @instance.exports.send(@wfunc).call
  end

  def test_opasgn_class_var
    assert_equal 900, @instance.exports.send(@wfunc).call
  end    

  def test_opasgn_embedded
    assert_equal 32, @instance.exports.send(@wfunc).call(10)
  end    

  def test_opasgn_global_var
    assert_equal 1, @instance.exports.send(@wfunc).call
  end    

  def test_opasgn_instance_method
    assert_equal 1110, @instance.exports.send(@wfunc).call
  end

  def test_opasgn_instance_var
    assert_equal 1400, @instance.exports.send(@wfunc).call
  end

  def test_opasgn_local_var
    assert_equal 400, @instance.exports.send(@wfunc).call(20)
  end

  def test_opasgn_setter
    assert_equal 98, @instance.exports.send(@wfunc).call(100)
  end

  def test_operator_on_object
    base = @instance.exports.test_c_base.call
    assert_equal 12*5, @instance.exports.send(@wfunc).call - base
  end

  def test_operator_precedence
    assert_equal 70304, @instance.exports.send(@wfunc).call
  end

  def test_operator_binary
    assert_equal 100, @instance.exports.test_c_test_unary_plus.call(90, 10)
    assert_equal  80, @instance.exports.test_c_test_unary_minus.call(90, 10)
    assert_equal 900, @instance.exports.test_c_test_unary_multiply.call(90, 10)
    assert_equal   9, @instance.exports.test_c_test_unary_divide.call(90, 10)
    assert_equal   0, @instance.exports.test_c_test_unary_modulo.call(90, 10)
    assert_equal  10, @instance.exports.test_c_test_unary_and.call(90, 10)
    assert_equal  90, @instance.exports.test_c_test_unary_or.call(90, 10)
    assert_equal  80, @instance.exports.test_c_test_unary_xor.call(90, 10)
    assert_equal   5, @instance.exports.test_c_test_unary_shiftr.call(90, 4)
    assert_equal 360, @instance.exports.test_c_test_unary_shiftl.call(90, 2)
  end

  def test_operator_relational
    assert_equal 0, @instance.exports.send(@wfunc).call
  end

  def test_operator_unary
    assert_equal -10, @instance.exports.test_c_test_unary_minus.call(10)
    assert_equal 0, @instance.exports.test_c_test_unary_not.call(1)
    assert_equal 0, @instance.exports.test_c_test_unary_not.call(1000)
    assert_equal 1, @instance.exports.test_c_test_unary_not.call(0)
  end

  def test_require
    assert_equal 200, @instance.exports.send(@wfunc).call
  end

  def test_require_embedded
    assert_equal 200, @instance.exports.send(@wfunc).call
  end

  def test_require_twice
    assert_equal 200, @instance.exports.send(@wfunc).call
  end

  def test_require_relative
    assert_equal 200, @instance.exports.send(@wfunc).call
  end

  def test_require_wat
    assert_equal 1001, @instance.exports.send(@wfunc).call
  end

  def test_require_wat_with_extension
    assert_equal 1001, @instance.exports.send(@wfunc).call
  end

  def test_require_with_extension
    assert_equal 200, @instance.exports.send(@wfunc).call
  end

  def test_attr_access_on_cvar
    assert_equal 10004, @instance.exports.send(@wfunc).call(5)
  end

  def test_attr_access_on_lvar
    assert_equal 10004, @instance.exports.send(@wfunc).call(5)
  end

  def test_attr_class_size
    assert_equal 28, @instance.exports.send(@wfunc).call
  end

  def test_attr_definition
    assert @instance.exports.respond_to? :test_i_rw
    assert @instance.exports.respond_to? :test_i_rw=
    assert @instance.exports.respond_to? :test_i_r
    assert !@instance.exports.respond_to?(:test_i_r=)
    assert !@instance.exports.respond_to?(:test_i_w)
    assert @instance.exports.respond_to? :test_i_w=
    assert_equal 111, @instance.exports.send(@wfunc).call
  end

  def test_attr_definition_with_type
    assert_equal 1_000_000_000_000, @instance.exports.send(@wfunc).call(1_000_000)
  end
end
