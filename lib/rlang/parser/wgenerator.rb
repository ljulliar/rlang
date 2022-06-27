# Rlang language, compiler and libraries
# Copyright (c) 2019-2022,Laurent Julliard and contributors
# All rights reserved.

# WAT generator for Rlang
# Rlang is a subset of the Ruby language that can be transpiled
# to WAT and then compiled to WASM. The Rubinius WASM virtual
# machine is written in Rlang.

# TODO: write a short documentation about what subset of Ruby is
# supported in Rlang

require_relative '../../utils/log'
require_relative './wnode'
require_relative './klass'
require_relative './module'
require_relative './module'

module Rlang::Parser

  ARITHMETIC_OPS_MAP = {
    :+  => :add,
    :-  => :sub,
    :*  => :mul,
    :&  => :and,
    :|  => :or,
    :^  => :xor,
    :<< => :shl
  }

  ARITHMETIC_SIGNED_OPS_MAP = {
    :/  => :div_x,
    :%  => :rem_x,
    :>> => :shr_x
  }

  RELATIONAL_OPS_MAP = {
    :==    => :eq,
    :!=    => :ne,
  }

  RELATIONAL_SIGNED_OPS_MAP = {
    :<     => :lt_x,
    :>     => :gt_x,
    :<=    => :le_x,
    :>=    => :ge_x
  }

  BOOLEAN_OPS_MAP = {
    :and   => :and,
    :or    => :or
  }

  UNARY_OPS_MAP = {
    :'!'   => :eqz,
    :'-@'  => :sub  # special case for unary - turned into (sub 0 x)
  }

  SIGNED_OPS = {
    signed: {div_x: :div_s, rem_x: :rem_s, shr_x: :shr_s, lt_x: :lt_s, gt_x: :gt_s,
      le_x: :le_s, ge_x: :ge_s},
    unsigned: {div_x: :div_u, rem_x: :rem_u, shr_x: :shr_u, lt_x: :lt_u, gt_x: :gt_u,
        le_x: :le_u, ge_x: :ge_u},
    nosign: {div_x: :div, lt_x: :lt, gt_x: :gt, le_x: :le, ge_x: :ge},
  }

  # Operators that can be legally used when doing
  # arithmetic on class instance (= object) pointers
  # Only unsigned relational operators make sense as pointers
  # are by nature unsigned integers
  LEGAL_CLASS_WASM_OPS = [:eq, :ne, :lt_u, :gt_u, :le_u, :ge_u, :add, :sub]

  # All operators with signed / unsigned variants
  ALL_SIGNED_OPS_MAP = [*ARITHMETIC_SIGNED_OPS_MAP, *RELATIONAL_SIGNED_OPS_MAP].to_h

  # All operators in on hash
  ALL_OPS_MAP = [*ARITHMETIC_OPS_MAP, *ARITHMETIC_SIGNED_OPS_MAP, *RELATIONAL_OPS_MAP, *RELATIONAL_SIGNED_OPS_MAP,
                 *BOOLEAN_OPS_MAP, *UNARY_OPS_MAP].to_h

  # Matrix of how to cast a Wtype to another
  CAST_OPS = {
    UI32:  { UI32: :cast_nope,  I32: :cast_wtype, UI64: :cast_extend, I64: :cast_extend, F32: :cast_convert, F64: :cast_convert, Class: :cast_wtype, none: :cast_error},
    I32:   { UI32: :cast_wtype, I32: :cast_nope,  UI64: :cast_extend, I64: :cast_extend, F32: :cast_convert, F64: :cast_convert, Class: :cast_wtype, none: :cast_error},
    UI64:  { UI32: :cast_wrap,  I32: :cast_wrap,  UI64: :cast_nope,   I64: :cast_wtype,  F32: :cast_convert, F64: :cast_convert, Class: :cast_error, none: :cast_error},    
    I64:   { UI32: :cast_wrap,  I32: :cast_wrap,  UI64: :cast_wtype,  I64: :cast_nope,   F32: :cast_convert, F64: :cast_convert, Class: :cast_error, none: :cast_error},    
    F32:   { UI32: :cast_trunc, I32: :cast_trunc, UI64: :cast_trunc,  I64: :cast_trunc,  F32: :cast_nope,    F64: :cast_promote, Class: :cast_error, none: :cast_error},    
    F64:   { UI32: :cast_trunc, I32: :cast_trunc, UI64: :cast_trunc,  I64: :cast_trunc,  F32: :cast_demote,  F64: :cast_nope,    Class: :cast_error, none: :cast_error},    
    Class: { UI32: :cast_wtype, I32: :cast_wtype, UI64: :cast_extend, I64: :cast_extend, F32: :cast_error,   F64: :cast_error,   Class: :cast_wtype, none: :cast_error},
    none:  { UI32: :cast_error, I32: :cast_error, UI64: :cast_error,  I64: :cast_error,  F32: :cast_error,   F64: :cast_error,   Class: :cast_error, none: :cast_error},
  }

  # Rlang class size method name
  SIZE_METHOD = :_size_

  # new template when object size > 0
  NEW_TMPL = %q{
  result :Object, :allocate, :%{default_wtype}
  def self.new(%{margs})
    result :"%{class_name}"
    object_ptr = Object.allocate(%{class_name}._size_).cast_to(:"%{class_name}")
    object_ptr.initialize(%{margs})
    return object_ptr
  end
  }

  # new template when object size is 0 (no instance var)
  # use 0 as the _self_ address in memory. It should never
  # be used anyway
  NEW_ZERO_TMPL = %q{
  def self.new(%{margs})
    result :"%{class_name}"
    object_ptr = 0.cast_to(:"%{class_name}")
    object_ptr.initialize(%{margs})
    return object_ptr
  end
  }

  # Do nothing initialize method
  DUMB_INIT_TMPL = %q{
  def initialize()
    result :nil
  end
  }

  # Dynamically allocate a string object
  STRING_NEW_TMPL = %q{
    String.new(%{ptr}, %{length})
  }

  # Dynamically allocate a string object
  ARRAY_NEW_TMPL = %q{
    Array%{elt_size_in_bits}.new(%{ptr}, %{length})
  }

  # Generate the wasm nodes and tree structure
  # ***IMPORTANT NOTE***
  # Unless otherwise stated all methods receive
  # the parent wnode as their first argument 
  # and must generate child nodes of this parent
  # Child node created is returned
  class WGenerator
    include Log
    attr_accessor :parser
    attr_reader :root, :wn_imports, :wn_exports, :wn_globals, :wn_data, :wn_code

    def initialize(parser)
      @parser = parser
      @root = WTree.new().root
      @new_count = 0
      @static_count = 0

      # Create section wnodes
      @wn_imports = WNode.new(:imports, @root)
      @wn_memory  = WNode.new(:memory, @root)
      @wn_exports = WNode.new(:exports, @root)
      @wn_globals = WNode.new(:globals, @root)
      @wn_data = WNode.new(:data, @root)

      # Module code generation
      @root.c(:module, module: parser.config[:module])

      # Memory code generation
      WNode.new(:insn, @wn_memory). \
        c(:memory, min: parser.config[:memory_min], max: parser.config[:memory_max])

      # define Object class and Kernel modules
      # and include Kernel in Object
      wn_object_class = self.klass(@root, [:Object], [])
      @object_class = wn_object_class.klass
      @root.klass = @object_class
      wn_kernel_module = self.module(@root, [:Kernel])
      self.include(wn_object_class, [:Kernel])

      # Create Class and Module classes
      # And Class inherits from module
      self.klass(@root, [:Module], [:Object])
      self.klass(@root, [:Class], [:Module])
    end

    # Create class and its basic methods (new, initialize and _size_)
    def klass(wnode, class_path, super_class_path)
      logger.debug "Defining klass #{class_path} < #{super_class_path}"
      # See if class already created
      if (k = wnode.find_class_or_module(class_path))
        return k.wnode
      end

      # Make sure super class is known like Ruby does
      if super_class_path.empty?
        # special case to bootstrap Object class
        if (class_path == [:Object] && wnode.in_root_scope?)
          sk = nil
        else
          sk = @object_class
          super_class_path << sk.path_name
        end
      else
        sk = wnode.find_class_or_module(super_class_path)
        raise "Unknown super class #{super_class_path}" unless sk
      end
      # Create class object and class wnode if it doesn't exist yet
      # only one level deep class for now so scope class is always
      # Object class
      if (class_path == [:Object] && wnode.in_root_scope?)
        k = wnode.create_class(class_path, super_class_path)
      else
        k = wnode.find_or_create_class(class_path, super_class_path)
      end
      # make sure the super class is correct in case class
      # was previously declared in a result directive where
      # no super class can be specified
      k.super_class = sk if sk
      # Create methods Class::new, Class#initialize and Class::_size_
      # (do not generate the code yet as the end user code may 
      # define its own implementation in the class body)
      k.wnode.find_or_create_method(k, :new, :class, k.wtype, true)
      k.wnode.find_or_create_method(k, :_size_, :class, WType::DEFAULT, true)    
      k.wnode.find_or_create_method(k, :initialize, :instance, WType.new(:none), true)    
      k.wnode
    end

    def comments(wnode, comments)
      # The gsub below is to handle =begin...=end block comments
      comments.each do |c|
        WNode.new(:comment, wnode).c(:comment, text: c.text.sub(/^\s*#/,'').gsub("\n", "\n;;"))
      end
    end

    # Create module object and module wnode 
    # if it doesn't exist yet
    def module(wnode, module_path)
      m = wnode.find_or_create_module(module_path)
      m.wnode
    end

    def include(wnode, module_path)
      m = wnode.find_module(module_path)
      raise "Unknown module #{module_path}. Please require module first." \
        unless m
      wnc = wnode.class_or_module_wnode
      raise "Cannot find scope class/module for included module!!" unless wnc
      wnc.klass.include(m) 
      m.included!
      wnc
    end

    def prepend(wnode, module_path)
      m = wnode.find_module(module_path)
      raise "Unknown module #{module_path}. Please require module first." \
        unless m
      wnc = wnode.class_or_module_wnode
      raise "Cannot find scope class/module for prepended module!!" unless wnc
      wnc.klass.prepend(m) 
      m.prepended!
      wnc
    end

    def extend(wnode, module_path)
      m = wnode.find_module(module_path)
      raise "Cannot find module #{module_path}. Please require module first." \
        unless m
      wnc = wnode.class_or_module_wnode
      raise "Cannot find scope class/module for included module!!" unless wnc
      wnc.klass.extend(m)
      m.extended!
      wnc
    end

    # Ahead of time method declaration and return type
    # Create corresponding classes and method objects as we known we'll
    # be calling them later on
    def declare_method(wnode, wtype, method_name, result_type)
      class_path = wtype.class_path
      logger.debug "Declaring method #{method_name} in class #{class_path}"
      klass = WNode.root.find_class_or_module(class_path)
      raise "Can't find class or module #{class_path} in method declaration" unless klass
      method_types = []
      if method_name[0] == '#'
        method_types << :instance
        method_types << :class if klass.const.module?
        mth_name = method_name[1..-1].to_sym
      else
        method_types << :class
        method_types << :instance if klass.const.module?
        mth_name = method_name.to_sym
      end
      mth = method_types.each do |mt|
        (m = wnode.find_or_create_method(klass, mth_name, mt, nil)).wtype = WType.new(result_type)
        logger.debug "Declared #{mt} method #{m.name} in class #{m.klass.name} with wtype #{m.wtype.name}"
        m
      end
      mth
    end
  
    # Postprocess ivars
    # (called at end of class parsing)
    def ivars_setup(wnode)
      wnc = wnode.class_wnode
      raise "Cannot find class for attributes definition!!" unless wnc
      klass = wnc.klass
      logger.debug "Postprocessing ivars for class #{klass.name}..."
      klass.ivars.each do |iv|
        iv.offset = klass.offset
        logger.debug "... ivar #{iv.name} has offset #{iv.offset}"
        # Update offset for next ivar
        klass.offset += iv.size
      end
    end

    # generate code for class attributes
    # (called at end of class parsing)
    def def_attr(wnode)
      klass = wnode.find_current_class_or_module()
      wnc = klass.wnode
      raise "Cannot find class for attributes definition!!" unless wnc
      # Process each declared class attribute
      klass.attrs.each do |attr|
        logger.debug("Generating accessors for attribute #{klass.name}\##{attr.name}")
        # Generate getter and setter methods wnode
        # unless method already implemented by user
        if attr.setter
          unless attr.setter.implemented?
            attr.setter.wnode = self.attr_setter(wnc, attr)
          else
            logger.debug "Attribute setter #{attr.setter.name} already defined. Skipping"
          end
        end
        if attr.getter
          unless attr.getter.implemented?
            attr.getter.wnode = self.attr_getter(wnc, attr)
          else
            logger.debug "Attribute getter #{attr.getter.name} already defined. Skipping"
          end
        end
      end

      # Also generate the Class::_size_ method
      # (needed for dynamic memory allocation
      #  by Object.allocate)
      size_method = wnc.find_or_create_method(klass, SIZE_METHOD, :class, WType::DEFAULT)
      unless size_method.wnode
        logger.debug("Generating #{size_method.klass.name}\##{size_method.name}")
        wns = WNode.new(:insn, wnc)
        wns.wtype = WType::DEFAULT
        wns.c(:class_size, func_name: size_method.wasm_name, 
              wasm_type: wns.wasm_type, size: wnc.class_size)
        size_method.wnode = wns
      end
    end

    # Generate attribute setter method wnode
    def attr_setter(wnode, attr)
      wnc = wnode.class_wnode
      wn_set = WNode.new(:insn, wnc, true)
      wn_set.c(:attr_setter, func_name: attr.setter.wasm_name, 
            attr_name: attr.wasm_name, wasm_type: attr.wasm_type,
            offset: attr.offset)
      wn_set
    end

    # Generate attribute getter method wnode
    def attr_getter(wnode, attr)
      wnc = wnode.class_wnode
      wn_get = WNode.new(:insn, wnc, true)
      wn_get.c(:attr_getter, func_name: attr.getter.wasm_name, 
            wasm_type: attr.wasm_type, offset: attr.offset)
      wn_get
    end

    def def_method(wnode, method_name, method_type)
      logger.debug("Defining #{method_type} method #{method_name}...")
      if (method = wnode.find_method(nil, method_name, method_type, true))
        logger.warn "Redefining #{method.klass.name},#{method_name}" if method.wnode
      else
        method = wnode.create_method(nil, method_name, method_type, nil, true)
      end

      # If it's the main method, give it the proper name in export if
      # specified on command line
      if method.klass.path_name == :Object && method.name == :main
        method.export_name = @parser.config[:start]
      end

      # Generate method definition wnode
      logger.debug("Generating wnode for #{method_type} method #{method_name}")
      wn = WNode.new(:method, wnode)
      method.wnode = wn
      wn.wtype = method.wtype
      wn.c(:func, func_name: wn.method.wasm_name)

      # Instance methods 1st argument is always self
      wn.create_marg(:_self_) if method.instance?
      logger.debug("Built #{method_type} method definition: wn.wtype #{wn.wtype}, wn.method #{wn.method}")
      wn
    end

    def import_method(wnode, module_name, function_name)
      # Create the import node
      (wn_import = WNode.new(:insn, self.wn_imports)).c(:import, module_name: module_name, function_name: function_name)
      wn_import.link = wnode
      wnode.method.imported!
      # now silence the method wnode so that
      # it doesn't generate WASM code in the code section
      wnode.silence!
      wn_import
    end

    def export_method(wnode, export_name)
      wnode.method.export!(export_name)
    end

    def params(wnode)
      wnm = wnode.method_wnode
      # use reverse to preserve proper param order
      wnm.method.margs.reverse.each do |marg|
        logger.debug("Prepending param #{marg}")
        wn = WNode.new(:insn, wnm, true)
        wn.wtype = marg.wtype
        wn.c(:param, name: marg.wasm_name, wasm_type: wn.wasm_type)
      end
    end

    def result(wnode)
      unless wnode.wtype.blank?
        wn = WNode.new(:insn, wnode, true)
        wn.wtype = wnode.wtype
        wn.c(:result, wasm_type: wn.wasm_type)      
      end
    end

    def locals(wnode)
      wnm = wnode.method_wnode
      wnm.method.lvars.reverse.each do |lvar|
        logger.debug("Prepending local #{lvar.inspect}")
        wn = WNode.new(:insn, wnm, true)
        wn.wtype = lvar.wtype
        wn.c(:local, name: lvar.wasm_name, wasm_type: wn.wasm_type)
      end
    end

    def inline(wnode, code, wtype=Type::I32)
      wn = WNode.new(:insn, wnode)
      wn.wtype = wnode.wtype
      wn.c(:inline, code: code)
      wn    
    end

    # Set constant
    def casgn(wnode, const)
      (wn = WNode.new(:insn, wnode)).wtype = const.wtype
      wn.c(:store, wasm_type: const.wtype)
      WNode.new(:insn, wn).c(:addr, value: const.address)
      wn
    end

    # Get constant
    def const(wnode, const)
      (wn = WNode.new(:insn, wnode)).wtype = const.wtype
      wn.c(:load, wasm_type: const.wasm_type)
      WNode.new(:insn, wn).c(:addr, value: const.address)
      wn
    end

    # Get constant addres
    def const_addr(wnode, const)
      (wn = WNode.new(:insn, wnode)).wtype = const.wtype
      wn.c(:addr, value: const.address)
      wn
    end

    # Set Global variable
    def gvasgn(wnode, gvar)
      (wn = WNode.new(:insn, wnode)).wtype = gvar.wtype
      wn.c(:global_set, var_name: gvar.name)
      wn
    end

    # Get Global variable
    def gvar(wnode, gvar)
      (wn = WNode.new(:insn, wnode)).wtype = gvar.wtype
      wn.c(:global_get, var_name: gvar.name)
      wn
    end

    # Call setter (on attr or instance variable)
    # This is the same as calling the corresponding setter
    def call_setter(wnode, wnode_recv, attr)
      wn = self.send_method(wnode, wnode_recv.wtype, attr.setter_name, :instance)
      # First argument of the setter must be the receiver
      wnode_recv.reparent_to(wn)
      wn
    end

    # Call getter (on attr or instance variable)
    # This is the same as calling the corresponding getter
    def call_getter(wnode, wnode_recv, attr)
      wn = self.send_method(wnode, wnode_recv.wtype, attr.getter_name, :instance)
      # First argument of the getter must always be the receiver
      wnode_recv.reparent_to(wn)
      wn
    end

    # Set instance variable
    def ivasgn(wnode, ivar)
      (wn = WNode.new(:insn, wnode)).wtype = ivar.wtype
      wn.c(:store_offset, wasm_type: ivar.wasm_type, offset: lambda { ivar.offset })
      self._self_(wn)
      wn
    end

    # Get instance variable. 
    def ivar(wnode, ivar)
      (wn = WNode.new(:insn, wnode)).wtype = ivar.wtype
      wn.c(:load_offset, wasm_type: ivar.wasm_type, offset: lambda { ivar.offset })
      self._self_(wn)
      wn
    end

    # Set class variable
    # Create the class variable storage node and
    # an empty expression node to populate later
    def cvasgn(wnode, cvar)
      (wn = WNode.new(:insn, wnode)).wtype = cvar.wtype
      wn.c(:store, wasm_type: cvar.wasm_type)
      WNode.new(:insn, wn).c(:addr, value: cvar.address)
      wn
    end

    # Get class variable
    def cvar(wnode, cvar)
      (wn = WNode.new(:insn, wnode)).wtype = cvar.wtype
      wn.c(:load, wasm_type: cvar.wasm_type)
      WNode.new(:insn, wn).c(:addr, value: cvar.address)
      wn
    end


    # Get class variable address
    def cvar_addr(wnode, cvar)
      (wn = WNode.new(:insn, wnode)).wtype = cvar.wtype
      wn.c(:addr, value: cvar.address)
      wn
    end

    # Create the local variable storage node 
    def lvasgn(wnode, lvar)
      (wn = WNode.new(:insn, wnode)).wtype = lvar.wtype
      wn.c(:local_set, var_name: lvar.wasm_name)
      wn
    end

    # Read local variable
    def lvar(wnode, lvar)
      (wn = WNode.new(:insn, wnode)).wtype = lvar.wtype
      wn.c(:local_get, var_name: lvar.wasm_name)
      wn
    end

    def drop(wnode)
      logger.debug "dropping result of #{wnode}, caller: #{caller_locations}"
      (wn = WNode.new(:insn, wnode)).c(:drop)
      wn
    end

    def nop(wnode)
      (wn = WNode.new(:insn, wnode)).c(:nop)
      wn
    end

    def int(wnode, wtype, value)
      (wn = WNode.new(:insn, wnode)).wtype = wtype
      wn.c(:const, wasm_type: wn.wasm_type, value: value)
      wn
    end

    def float(wnode, wtype, value)
      (wn = WNode.new(:insn, wnode)).wtype = wtype
      wn.c(:const, wasm_type: wn.wasm_type, value: value)
      wn
    end

    # Generate a phony node (generally used to create 
    # a wnode subtree under the phony node and later
    # reparent it to the proper place in the wtree)
    def phony(wnode, type=:none)
      WNode.new(type, wnode)
    end

    # Static string data allocation
    def allocate_string_static_data(string, data_label)
      # if string is empty do not allocate any memory space
      DAta.append(data_label.to_sym, string) unless string.empty?
    end

    # Static new string object
    def string_static_new(wnode, string)
      klass = wnode.find_current_class_or_module()
      data_label = "#{klass.name}_string_#{@static_count += 1}"
      # Allocate string data statically
      # Note : data_stg is nil if string is empty
      data_stg = self.allocate_string_static_data(string, data_label)
      # align on :I32 boundary
      # then allocate the String object attributes
      # and set them up
      DAta.align(4)
      data_len = DAta.append("#{data_label}_len".to_sym, string.length, WType::DEFAULT)
      data_ptr = DAta.append("#{data_label}_ptr".to_sym, data_stg ? data_stg.address : 0, WType::DEFAULT)
      # Generate address wnode
      (wn_object_addr = WNode.new(:insn, wnode)).c(:addr, value: data_len.address)
      wn_object_addr.wtype = WType.new(:String)
      wn_object_addr
    end

    # Dynamic new string object
    def string_dynamic_new(wnode, string)
      klass = wnode.find_current_class_or_module()
      data_label = "#{klass.name}_string_#{@static_count += 1}"
      # Note : data_stg is nil if string is empty
      data_stg = self.allocate_string_static_data(string, data_label)
      string_new_source = STRING_NEW_TMPL % {
        ptr: data_stg ? data_stg.address : 0,
        length: string.length
      }
      #puts string_new_source;exit
      self.parser.parse(string_new_source, wnode)
    end

    # Static array data allocation
    def allocate_array_static_data(array, data_label)
      # Append each array element to the same data section
      label = data_label.to_sym
      data_arr = nil
      # Do not allocate memory space if array is empty
      array.each { |elt| data_arr = DAta.append(label, elt) }
      data_arr
    end

    # Static new array object
    def array_static_new(wnode, array)
      klass = wnode.find_current_class_or_module()
      data_label = "#{klass.name}_array_#{@static_count += 1}"
      # Allocate array data statically
      # Note : data_arr is nil if string is empty
      data_arr = self.allocate_array_static_data(array, data_label)
      # align on :I32 boundary
      # then allocate the Array object attributes
      # and set them up
      DAta.align(4)
      data_count = DAta.append("#{data_label}_count".to_sym, array.length, WType::DEFAULT)
      data_ptr   = DAta.append("#{data_label}_ptr".to_sym, data_arr ? data_arr.address : 0, WType::DEFAULT)
      # Generate address wnode
      (wn_object_addr = WNode.new(:insn, wnode)).c(:addr, value: data_count.address)
      wn_object_addr.wtype = WType.new(:Array32)
      wn_object_addr
    end

    # Dynamic new array object
    def array_dynamic_new(wnode, array)
      klass = wnode.find_current_class_or_module()
      data_label = "#{klass.name}_array_#{@static_count += 1}"
      # Note : data_arr is nil if string is empty
      data_arr = self.allocate_array_static_data(array, data_label)
      array_new_source = ARRAY_NEW_TMPL % {
        elt_size_in_bits: WTYPE::DEFAULT.size * 8,
        ptr: data_arr ? data_arr.address : 0,
        count: array.length
      }
      #puts array_new_source;exit
      self.parser.parse(array_new_source, wnode)
    end

    # TYPE CASTING methods
    # All the cast_xxxx methods below returns
    # the new wnode doing the cast operation
    # or the same wnode if there is no additional code
    # for the cast operation

    # No casting. Return node as is.
    def cast_nope(wnode, wtype, signed)
      wnode
    end

    # Cast by extending to a wtype of larger bit size
    # (e.g. I32 to I64)
    def cast_extend(wnode, wtype, signed)
      if (wnode.template == :const)
        # it's a WASM const, simply change the wtype
        wnode.wtype = wtype
        wn_cast_op = wnode
      else
        wn_cast_op = wnode.insert(:insn)
        wn_cast_op.wtype = wtype
        sign = signed ? 's' : 'u'
        source_type = wnode.wasm_type
        wasm_type = wn_cast_op.wasm_type
        wn_cast_op.c(:extend , wasm_type: wasm_type, source_type: source_type, sign: sign)
      end
      wn_cast_op
    end

    # Cast by simply changing the node wtype
    # No change in native WASM type
    # (e.g. casting an object pointer to I32)
    def cast_wtype(wnode, wtype, signed)
      # Don't cast blindly. Check that source and target
      # have the same bit size (e.g. Object pointers, I32, UI32
      # are the same size, )
      if wnode.wtype.size == wtype.size
        wnode.wtype = wtype
      else
        cast_error(wnode, wtype, signed)
      end
      wnode
    end

    # Cast by wraping a wtype to a smaller size
    # (e.g. I64 to I32)
    def cast_wrap(wnode, wtype, signed)
      if (wnode.template == :const)
        # it's a WASM const, simply change the wtype
        wnode.wtype = wtype
        wn_cast_op = wnode
      else
        wn_cast_op = wnode.insert(:insn)
        wn_cast_op.wtype = wtype
        wn_cast_op.c(:wrap_i64, wasm_type: wn_cast_op.wasm_type)
      end
      wn_cast_op
    end

    # Cast by promoting a wtype to a larger size
    # (e.g. F32 to F64)
    def cast_promote(wnode, wtype, signed)
      if (wnode.template == :const)
        # it's a WASM const, simply change the wtype
        wnode.wtype = wtype
        wn_cast_op = wnode
      else
        wn_cast_op = wnode.insert(:insn)
        wn_cast_op.wtype = wtype
        wn_cast_op.c(:promote, wasm_type: wn_cast_op.wasm_type)
      end
      wn_cast_op
    end

    # Cast by demoting a wtype to a larger size
    # (e.g. F64 to F32)
    def cast_demote(wnode, wtype, signed)
      if (wnode.template == :const)
        # it's a WASM const, simply change the wtype
        wnode.wtype = wtype
        wn_cast_op = wnode
      else
        wn_cast_op = wnode.insert(:insn)
        wn_cast_op.wtype = wtype
        wn_cast_op.c(:demote, wasm_type: wn_cast_op.wasm_type)
      end
      wn_cast_op
    end

    # Truncate a float wtype to a smaller precision integer type
    # (e.g. F32 to I32, F64 to I64, ...)
    def cast_trunc(wnode, wtype, signed)
      if (wnode.template == :const)
        # it's a WASM const, simply change the wtype
        wnode.wtype = wtype
        wn_cast_op = wnode
      else
        wn_cast_op = wnode.insert(:insn)
        wn_cast_op.wtype = wtype
        sign = signed ? 's' : 'u'
        source_type = wnode.wasm_type
        wasm_type = wn_cast_op.wasm_type
        wn_cast_op.c(:trunc , wasm_type: wasm_type, source_type: source_type, sign: sign)
      end
      wn_cast_op
    end

    # Covert an integer wtype to a possibly smaller precision
    # float type  (e.g. I32 to F32,I64 to F32, ...)
    def cast_convert(wnode, wtype, signed)
      if (wnode.template == :const)
        # it's a WASM const, simply change the wtype
        wnode.wtype = wtype
        wn_cast_op = wnode
      else
        wn_cast_op = wnode.insert(:insn)
        wn_cast_op.wtype = wtype
        sign = signed ? 's' : 'u'
        source_type = wnode.wasm_type
        wasm_type = wn_cast_op.wasm_type
        wn_cast_op.c(:convert , wasm_type: wasm_type, source_type: source_type, sign: sign)
      end
      wn_cast_op
    end

    # Cast operation not yet supported
    def cast_notyet(wnode, wtype, signed)
      raise "Type cast from #{wnode.wtype} to #{wtype} not supported yet"
    end

    # Cast operation is invalid
    def cast_error(wnode, wtype, signed)
      raise "Cannot cast type #{wnode.wtype} to #{wtype}. Time to fix your code :-)"
    end

    # cast an expression to a different type
    # if same type do nothing
    # - wnode: the wnode to type cast 
    # - wtype: the wtype to cast wnode to
    # - signed: whether the cast wnode must be interpreted as a signed value
    #
    # TODO: simplify this complex method (possibly by using
    # a conversion table source type -> destination type)
    def cast(wnode, wtype, signed=false)
      logger.debug "Casting wnode: #{wnode}, wtype: #{wtype}, wnode ID: #{wnode.object_id}"
      src_type  = (wnode.wtype.native? ? wnode.wtype.name : :Class)
      dest_type = (wtype.native? ? wtype.name : :Class)
      cast_method = CAST_OPS[src_type] && CAST_OPS[src_type][dest_type] || :cast_error
      logger.debug "Calling cast method: #{cast_method}"
      wn_cast_op = self.send(cast_method, wnode, wtype, signed)
      logger.debug "After type cast: wnode: #{wn_cast_op}, wtype: #{wtype}, wnode ID: #{wn_cast_op.object_id}"
      wn_cast_op
    end

    # just create a wnode for the WASM operator
    # Do not set wtype or a code template yet,
    # wait until operands type is known (see
    # operands below)
    def native_operator(wnode, operator, wtype=WType.new(:none))
      if (op = ALL_OPS_MAP[operator])
        (wn_op = WNode.new(:insn, wnode)).wtype = wtype
        wn_op.c(:operator, wasm_type: wn_op.wasm_type, operator: op)
        logger.debug "Creating operator #{operator} wnode: #{wn_op}"
        # special case for - unary operator transformed into (0 - x)
        WNode.new(:insn, wn_op).c(:const, wasm_type: wn_op.wasm_type, value: 0) if operator == :-@
        wn_op
      else
        raise "operator '#{operator}' not supported"
      end
    end

    # Finish the setting of the operator node, 
    # attach operands and see if they need implicit
    # type casting
    def operands(wnode_op, wnode_recv, wnode_args)
      logger.debug "Processing operands in operator wnode: #{wnode_op}..."
      # Do not post process operands if the operator
      # wnode is a call (= overloaded operator)
      # and not a native operand
      if wnode_op.template == :call
        logger.debug "Doing nothing because it's a func call..."
        return wnode_op
      end

      # A native operator only expects 0 (unary) or 1 (binary)
      # argument in addition to the receiver 
      raise "only 0 or 1 operand expected (got #{wnode_args.count})" if wnode_args.count > 1
      op = wnode_op.wargs[:operator]
      #wnode_recv = wnode_op.children[0]
      #wnode_args = wnode_op.children[1..-1]
      # First find out the wtype that has precedence
      leading_wtype = self.class.leading_wtype(wnode_recv, *wnode_args)
      
      wnode_op.wtype = leading_wtype
      logger.debug "leading type cast: #{leading_wtype}"

      # Attach receiver and argument to the operator wnode
      # type casting them if necessary
      # Note : normally for an operator there is only one argument
      # but process args as if they were many one day.
      logger.debug "Perform implicit type casting of receviver and operator arg(s)"
      self.cast(wnode_recv, leading_wtype).reparent_to(wnode_op)
      wnode_args.each do |wna|
        self.cast(wna, leading_wtype).reparent_to(wnode_op)
      end

      # Once operands casting is done, see if we need the signed, unsigned
      # or nosign (float) version of the native operator
      # NOTE : At this stage, after the operands casting both of them
      # should either be signed or unsigned, hence the XNOR sanity check
      # below
      if ALL_SIGNED_OPS_MAP.values.include? op
        if !((signed = wnode_recv.wtype.signed?) ^ (wnode_args.empty? ? true : wnode_args.first.wtype.signed?))
          if wnode_recv.wtype.float?
            op_category = :nosign
          elsif signed
            op_category = :signed
          else
            op_category = :unsigned
          end
          wnode_op.wargs[:operator] = SIGNED_OPS[op_category][op]
          logger.debug "Receiver has wtype #{wnode_recv.wtype} / Argument has wtype #{wnode_args.first.wtype}"
          logger.debug "Replacing #{op} operator with #{wnode_op.wargs[:operator]}"
          op = wnode_op.wargs[:operator]
        else
          raise "Type mismatch between operands. Receiver is #{wnode_recv.wtype} and argument is #{wnode_args.first.wtype}"
        end
      end

      # if the receiver is a class object and not
      # a native integer then pointer arithmetic
      # applies (like in C)
      if wnode_recv.wtype.class?
        raise "Only #{LEGAL_CLASS_WASM_OPS.join(', ')} operators are supported on objects (got #{op} in #{wnode_op})" \
          unless LEGAL_CLASS_WASM_OPS.include?(op)
        # if :add or :sub operator then multiply arg by size of object
        # like in C
        if [:add, :sub].include? op
          (wn_mulop = WNode.new(:insn, wnode_op)).wtype = WType::DEFAULT
          wn_mulop.c(:operator, wasm_type: wn_mulop.wasm_type, operator: :mul)
          WNode.new(:insn, wn_mulop).c(:call, func_name: "$#{wnode_recv.wtype.name}::#{SIZE_METHOD}")
          wnode_args.first.reparent_to(wn_mulop)
        else
          # It's a relational operator. In this case
          # the type of the operator node is always the
          # default type because a comparison between 
          # object pointers gives a boolean (0 or 1)
          wnode_op.wtype = WType::DEFAULT
        end
      end
      logger.debug "Operands in operator wnode after postprocessing: #{wnode_op}..."
      wnode_op
    end

    # Statically allocate an object in data segment
    # with the size of the class
    def static_new(wnode, class_path)
      klass = wnode.find_class_or_module(class_path)
      if klass.size > 0
        data_label = "#{klass.path_name}_new_#{@new_count += 1}"
        data = DAta.new(data_label.to_sym, "\x00"*klass.wnode.class_size)
        address = data.address
      else
        # TODO: point to address 0. It is not safe but normally
        # this class is without attribute so the code will never
        # use memory address to access attribute
        address = 0
      end
      (wn_object_addr = WNode.new(:insn, wnode)).c(:addr, value: address)
      # VERY IMPORTANT the wtype of this node is the Class name !!!
      wn_object_addr.wtype = WType.new(klass.path_name)
      wn_object_addr
    end

    # Create the dynamic new method. It allocates memory
    # for the object created and calls initialize
    def def_new(wnode_class)
      k = wnode_class.find_current_class_or_module()
      logger.debug "Defining new method for #{k.name}"
      # no need to define new method for native types
      return if wnode_class.klass.wtype.native?
      if (new_mth = wnode_class.find_method(k, :new, :class, true))
        return if new_mth.implemented? # already implemented
      end
      
      logger.debug "Creating code for #{k.name}.new"
      # Find initialize method and use the same method args for new
      init_method = wnode_class.find_method(k, :initialize, :instance, true)
      new_tmpl = wnode_class.class_size.zero? ? NEW_ZERO_TMPL : NEW_TMPL
      new_source = new_tmpl % {
        default_wtype: WType::DEFAULT.name,
        class_name: k.path_name,
        # Do not pass _self_ argument to the new method of course !!
        margs: init_method.margs.reject {|ma| ma._self_?}.map(&:name).join(', '), 
        class_size: wnode_class.class_size
      }
      new_mth.wnode = self.parser.parse(new_source, wnode_class)
    end

    # Define a dumb initialize method if not implemented
    # already in user code
    def def_initialize(wnode_class)
      k = wnode_class.find_current_class_or_module()
      # no new/initialize method for native types
      return if WType.new(k.path_name).native? 
      # generate code for a dumb initialize method if not defined
      # in user code
      if (init_mth = wnode_class.find_method(k, :initialize, :instance, true))
        return if init_mth.wnode # already implemented
      end
      logger.debug "Creating MEthod and code for #{k.name}#initialize"
      init_source = DUMB_INIT_TMPL
      init_mth.wnode = self.parser.parse(init_source, wnode_class)
    end

    # generate code for method call
    def send_method(wnode, class_path, method_name, method_type)
      logger.debug "In call generator for #{class_path}::#{method_name}"
      if k = wnode.find_class_or_module(class_path)
        method = wnode.find_method(k, method_name, method_type)
        if k.wtype.native? && ALL_OPS_MAP.has_key?(method_name)
          # An Rlang method exist for this class but methods corresponding to 
          # Webassembly native operators applied to native Webassembly types
          # (I32, I64, F32, F64) **cannot** be overriden by instance methods
          # in Rlang code
          if method
            logger.warn "Rlang #{class_path}::#{method_name} method ignored. Native operator has precedence"
          end
          logger.debug "Apply native operator #{method_name} to native wtype  #{class_path}"
          wn_call = self.native_operator(wnode, method_name, WType.new(class_path))
        elsif !k.wtype.native? && ALL_OPS_MAP.has_key?(method_name) && method.nil?
          # Similarly if the Class is not a native type (a regular class)
          # and the Class doesn't provide its own method implementation of the native
          # operator then apply the native operands
          logger.debug "Apply native operator #{method_name} to class found : #{class_path}"
          wn_call = self.native_operator(wnode, method_name, WType.new(class_path))
        elsif method
          logger.debug "Found method #{method.name} in class #{method.klass.name}"
          (wn_call = WNode.new(:insn, wnode)).c(:call, func_name: method.wasm_name)
          wn_call.wtype = method.wtype
          wn_call
        else
          raise "Unknown method '#{method_name}' in class #{class_path}"
        end
      elsif ALL_OPS_MAP.has_key? method_name
        # It is a native Wasm operator
        logger.debug "Native operator found : #{class_path}::#{method_name}"
        wn_call = self.native_operator(wnode, method_name, WType.new(class_path))
      else
        raise "Unknown method '#{method_name}' in class #{class_path}"
      end
      wn_call
    end

    # self in an instance context is passed as the first argument
    # of a method call
    def _self_(wnode)
      (wns = WNode.new(:insn, wnode)).c(:local_get, var_name: '$_self_')
      wns.wtype = WType.new(wnode.class_name)
      wns
    end

    def return(wnode)
      (wn = WNode.new(:insn, wnode)).c(:return)
      wn
    end

    def if(wnode)
      (wn = WNode.new(:insn, wnode)).c(:if)
      wn
    end

    def then(wnode)
      (wn = WNode.new(:insn, wnode)).c(:then)
      wn
    end
    
    def else(wnode)
      (wn = WNode.new(:insn, wnode)).c(:else)
      wn
    end

    def while(wnode)
      (wnb = WNode.new(:insn, wnode)).c(:block, label: wnb.set_label) 
      (wnl = WNode.new(:insn, wnb)).c(:loop, label: wnl.set_label) 
      (wnbi = WNode.new(:insn, wnl)).c(:br_if, label: wnb.label)
      return wnb,wnbi,wnl
    end

    # This is a post processing of the while
    # exp wnode because br_if requires to 
    # negate the original while condition
    # Note the wasm type of a condition testing
    # always returns an i32
    def while_cond(wnode, wnode_cond_exp)
      wn_eqz = WNode.new(:insn, wnode)
      wn_eqz.c(:eqz, wasm_type: 'i32')
      wnode_cond_exp.reparent_to(wn_eqz)
      wn_eqz
    end

    # add the unconditional looping branch at
    # the end of the while
    def while_end(wnode)
      (wnwe = WNode.new(:insn, wnode)).c(:br, label: wnode.label)
      wnwe
    end

    def break(wnode)
      # look for block wnode upper in the tree
      # and branch to that label
      (wn = WNode.new(:insn, wnode)).c(:br, label: wnode.block_wnode.label)
      wn
    end

    def next(wnode)
      # look for loop wnode upper in the tree
      # branch to that label
      (wn = WNode.new(:insn, wnode)).c(:br, label: wnode.loop_wnode.label)
      wn
    end

    private
    # Determine which wasm type has precedence among
    # all wnodes
    def self.leading_wtype(*wnodes)
      WType.leading(wnodes.map(&:wtype))
    end
  end
end