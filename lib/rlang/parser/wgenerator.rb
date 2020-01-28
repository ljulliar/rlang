# Rubinius WebAssembly VM
# Copyright (c) 2019, Laurent Julliard and contributors
# All rights reserved.

# WAT generator for Rlang
# Rlang is a subset of the Ruby language that can be transpiled
# to WAT and then compiled to WASM. The Rubinius WASM virtual
# machine is written in Rlang.

# TODO: write a short documentation about what subset of Ruby is
# supported in Rlang

require_relative '../../utils/log'
require_relative './wnode'

module Rlang::Parser

  ARITHMETIC_OPS_MAP = {
    :+  => :add,
    :-  => :sub,
    :*  => :mul,
    :/  => :div_u,
    :%  => :rem_u,
    :&  => :and,
    :|  => :or,
    :^  => :xor,
    :>> => :shr_u,
    :<< => :shl
  }

  RELATIONAL_OPS_MAP = {
    :==    => :eq,
    :!=    => :ne,
    :'<s'  => :lt_s,
    :<     => :lt_u,
    :'>s'  => :gt_s,
    :>     => :gt_u,
    :'<=s' => :le_s,
    :<=    => :le_u,
    :'>=s' => :ge_s,
    :>=    => :ge_u
  }

  BOOLEAN_OPS_MAP = {
    :and   => :and,
    :or    => :or
  }

  UNARY_OPS_MAP = {
    :'!'   => :eqz
  }

  # Matrix of how to cast a WASM type to another
  CAST_OPS = {
    I32: { I32: :cast_nope, I64: :cast_extend, F32: :cast_notyet, F64: :cast_notyet, Class: :cast_wtype, none: :cast_error},
    I64: { I32: :cast_wrap, I64: :cast_nope, F32: :cast_notyet, F64: :cast_notyet, Class: :cast_error, none: :cast_error},    
    F32: { I32: :cast_notyet, I64: :cast_notyet, F32: :cast_nope, F64: :cast_notyet, Class: :cast_error, none: :cast_error},    
    F64: { I32: :cast_notyet, I64: :cast_notyet, F32: :cast_notyet, F64: :cast_nope, Class: :cast_error, none: :cast_error},    
    Class: { I32: :cast_wtype, I64: :cast_extend, F32: :cast_error, F64: :cast_error, Class: :cast_wtype, none: :cast_error},
    none: { I32: :cast_error, I64: :cast_error, F32: :cast_error, F64: :cast_error, Class: :cast_error, none: :cast_error},
  }

  # Generate the wasm nodes and tree structure
  # ***IMPORTANT NOTE***
  # Unless otherwise stated all methods receive
  # the parent wnode as their first argument 
  # and must generate child nodes of this parent
  class WGenerator
    include Log
    attr_accessor :parser
    attr_reader :root

    def initialize(parser)
      @parser = parser
      @root = WTree.new().root
      @new_count = 0
    end

    def klass(wnode, klass_name)
      wn = WNode.new(:class, wnode)
      wn.class_name = klass_name
      wn.wtype = WType.new(wn.class_name)
      WNode.root.class_wnodes << wn
      wn
    end

    def attributes(wnode)
      wnc = wnode.class_wnode
      return if wnc.wattrs.empty?
      # Process each declared attribute
      offset = 0
      wnc.wattrs.each do |wa|
        logger.debug("Generating accessors for attribute #{wa}")
        # Generate getter and setter methods wnode
        wattr_setter(wnc, wa, offset)
        wattr_getter(wnc, wa, offset)
        # Update offset
        offset += wa.wtype.size
      end

      # Also generate the Class::size method
      size_method = wnc.create_method(:size, nil, WType::DEFAULT, :class)
      wns = WNode.new(:insn, wnc, true)
      wns.wtype = WType::DEFAULT 
      wns.c(:class_size, func_name: size_method.wasm_name, 
            wtype: wns.wasm_type, size: wnc.class_size)
    end

    # Generate attribute setter method wnode
    def wattr_setter(wnode, wattr, offset)
      wnc = wnode.class_wnode
      wn_set = WNode.new(:insn, wnc, true)
      wn_set.c(:wattr_writer, func_name: wattr.setter.wasm_name, 
            wattr_name: wattr.wasm_name, wtype: wattr.wasm_type,
            offset: offset)
      wn_set
    end

    # Generate attribute getter method wnode
    def wattr_getter(wnode, wattr, offset)
      wnc = wnode.class_wnode
      wn_get = WNode.new(:insn, wnc, true)
      wn_get.c(:wattr_reader, func_name: wattr.getter.wasm_name, 
            wattr_name: wattr.wasm_name, wtype: wattr.wasm_type,
            offset: offset)
      wn_get
    end

    def instance_method(wnode, method)
      logger.debug("Generating wnode for instance method #{method.inspect}")
      wn = WNode.new(:method, wnode)
      wn.method = method # must be set before calling func_name
      wn.wtype = method.wtype
      wn.c(:func, func_name: wn.method.wasm_name)
      # Also declare a "hidden" parameter representing the
      # pointer to the instance (always default wtype)
      wn.create_marg(:_self_)
      logger.debug("MEthod built: #{wn.method.inspect}")
      wn
    end

    def class_method(wnode, method)
      logger.debug("Generating wnode for class method #{method}")
      wn = WNode.new(:method, wnode)
      wn.method = method # must be set before calling func_name
      wn.wtype = method.wtype
      wn.c(:func, func_name: wn.method.wasm_name)
      logger.debug("Building method: wn.wtype #{wn.wtype}, wn.method #{wn.method}")
      wn
    end

    def params(wnode)
      wnode = wnode.method_wnode
      # use reverse to preserve proper param order
      wnode.margs.reverse.each do |marg|
        logger.debug("Prepending param #{marg}")
        wn = WNode.new(:insn, wnode, true)
        wn.wtype = marg.wtype
        wn.c(:param, name: marg.wasm_name)
      end
    end

    def result(wnode)
      unless wnode.wtype.blank?
        wn = WNode.new(:insn, wnode, true)
        wn.wtype = wnode.wtype
        wn.c(:result)      
      end
    end

    def locals(wnode)
      wnode = wnode.method_wnode
      wnode.lvars.reverse.each do |lvar|
        logger.debug("Prepending local #{lvar.inspect}")
        wn = WNode.new(:insn, wnode, true)
        wn.wtype = lvar.wtype
        wn.c(:local, name: lvar.wasm_name)
      end
    end

    def inline(wnode, code, wtype=Type::I32)
      wn = WNode.new(:insn, wnode)
      wn.wtype = wnode.wtype
      wn.c(:inline, code: code)
      wn    
    end

    # Constant assignment doesn't generate any code
    # A Data object is instantiated and initialized
    # when the Const object is created in parser
    def casgn(wnode, const)
    end

    # Read class variable
    def const(wnode, const)
      (wn = WNode.new(:insn, wnode)).wtype = const.wtype
      wn.c(:load, wtype: const.wtype, var_name: const.wasm_name)
      WNode.new(:insn, wn).c(:addr, value: const.address)
      wn
    end

    # Global variable assignment
    def gvasgn(wnode, gvar)
      (wn = WNode.new(:insn, wnode)).wtype = gvar.wtype
      wn.c(:global_set, var_name: gvar.name)
      wn
    end

    # Global variable read
    def gvar(wnode, gvar)
      (wn = WNode.new(:insn, wnode)).wtype = gvar.wtype
      wn.c(:global_get, var_name: gvar.name)
      wn
    end

    # Create the class variable storage node and
    # an empty expression node to populate later
    def cvasgn(wnode, cvar)
      (wn = WNode.new(:insn, wnode)).wtype = cvar.wtype
      wn.c(:store, wtype: cvar.wtype)
      WNode.new(:insn, wn).c(:addr, value: cvar.address)
      wn
    end

    # Read class variable
    def cvar(wnode, cvar)
      (wn = WNode.new(:insn, wnode)).wtype = cvar.wtype
      wn.c(:load, wtype: cvar.wtype, var_name: cvar.wasm_name)
      WNode.new(:insn, wn).c(:addr, value: cvar.address)
      wn
    end

    # Create the local variable storage node 
    def lvasgn(wnode, lvar)
      (wn = WNode.new(:insn, wnode)).wtype = lvar.wtype
      wn.c(:local_set, wtype: lvar.wtype, var_name: lvar.wasm_name)
      wn
    end

    # Read local variable
    def lvar(wnode, lvar)
      (wn = WNode.new(:insn, wnode)).wtype = lvar.wtype
      wn.c(:local_get, wtype: lvar.wtype, var_name: lvar.wasm_name)
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
      wn.c(:const, wtype: wtype, value: value)
      wn
    end

    def float(wnode, wtype, value)
      (wn = WNode.new(:insn, wnode)).wtype = wtype
      wn.c(:const, wtype: wtype, value: value)
      wn
    end

    # All the cast_xxxx methods below returns
    # the new wnode doing the cast operation
    # or the same wnode if there is no additional code
    # for the cast operation
    def cast_nope(wnode, wtype, signed)
      # Do nothing
      wnode
    end

    def cast_extend(wnode, wtype, signed)
      if (wnode.template == :const)
        # it's a WASM const, simply change the wtype
        wnode.wtype = wtype
        wn_cast_op = wnode
      else
        wn_cast_op = wnode.insert(:insn)
        wn_cast_op.wtype = wtype
        wn_cast_op.c(signed ? :extend_i32_s : :extend_i32_u , wtype: wtype)
      end
      wn_cast_op
    end

    def cast_wtype(wnode, wtype, signed)
      if (wnode.wtype.default? && wtype.class?) || 
         (wnode.wtype.class? && wtype.default?) ||
         (wnode.wtype.class? && wtype.class?)
        wnode.wtype = wtype
      else
        cast_error(wnode, wtype, signed)
      end
      wnode
    end

    def cast_wrap(wnode, wtype, signed)
      if (wnode.template == :const)
        # it's a WASM const, simply change the wtype
        wnode.wtype = wtype
        wn_cast_op = wnode
      else
        wn_cast_op = wnode.insert(:insn)
        wn_cast_op.wtype = wtype
        wn_cast_op.c(:wrap_i64, wtype: wtype)
      end
      wn_cast_op
    end

    def cast_notyet(wnode, wtype, signed)
      raise "Type cast from #{wnode.wtype} to #{wtype} not supported yet"
    end

    def cast_error(wnode, wtype, signed)
      raise "Cannot cast type #{src} to #{dest}. Time to fix your code :-)"
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
      logger.debug "wnode: #{wnode}, wtype: #{wtype}"
      src_type  = (wnode.wtype.native? ? wnode.wtype.name : :Class)
      dest_type = (wtype.native? ? wtype.name : :Class)
      cast_method = CAST_OPS[src_type] && CAST_OPS[src_type][dest_type] || :cast_error

      wn_cast_op = self.send(cast_method, wnode, wtype, signed)
      logger.debug "After type cast: wnode: #{wn_cast_op}, wtype: #{wtype}"
      wn_cast_op
    end

    # just create a wnode for the WASM operator
    # Do not set wtype or a code template yet,
    # wait until operands type is known (see
    # operands below)
    def operator(wnode, operator, wtype=WType.new(:none))
      if (op = (ARITHMETIC_OPS_MAP[operator] || 
                RELATIONAL_OPS_MAP[operator] ||
                BOOLEAN_OPS_MAP[operator]    ||
                UNARY_OPS_MAP[operator]  ))
        (wn_op = WNode.new(:insn, wnode)).c(:operator, operator: op)
        wn_op.wtype = wtype
        wn_op
      else
        raise "operator '#{operator}' not supported"
      end
    end

    # finish the setting of the operator node and
    # attach operands
    def operands(wnode_op, wnode_recv, wnode_args)
      raise "only 0 or 1 operand expected (got #{wnode_args.count})" if wnode_args.count > 1
      op = wnode_op.wargs[:operator]
      # First find out the wtype that has precedence
      wtype = self.class.leading_wtype(wnode_recv, *wnode_args)
      
      wnode_op.wtype = wtype
      logger.debug "leading type cast: #{wtype}"

      # Attach receiver and argument to the operator wnode
      # type casting them if necessary
      self.cast(wnode_recv, wtype).reparent_to(wnode_op)
      self.cast(wnode_args.first, wtype).reparent_to(wnode_op) unless wnode_args.empty?

      # if the receiver is a class object and not
      # a native integer then pointer arithmetic
      # applies (like in C)
      if wnode_recv.wtype.class?
        legal_ops = RELATIONAL_OPS_MAP.values + [:add, :sub]
        raise "Only #{legal_ops.join(', ')} operators are supported on objects (got #{op} in #{wnode_op})" \
          unless legal_ops.include?(op)
        # if + or - operator then multiply arg by size of object
        if [:add, :sub].include? wnode_op.wargs[:operator]
          (wn_mulop = WNode.new(:insn, wnode_op)).c(:operator, operator: :mul)
          WNode.new(:insn, wn_mulop).c(:const, 
            value: lambda { wnode_recv.find_class(wnode_recv.wtype.name).class_size })
          wnode_args.first.reparent_to(wn_mulop)
        else
          # It's a relational operator. In this case
          # the type of the operator node is always the
          # default type because a comparison between 
          # object pointers gives a boolean (0 or 1)
          wnode_op.wtype = WType::DEFAULT
        end
      end
      wnode_op
    end

    # Statically allocate an object in data segment
    # with the size of the class
    def new(wnode, class_name)
      class_wnode = wnode.find_class(class_name)
      if class_wnode.class_size > 0
        data_label = "#{class_name}_new_#{@new_count += 1}"
        data = DAta.new(data_label.to_sym, "\x00"*class_wnode.class_size)
        address = data.address
      else
        # TODO: point to address 0. It is not safe but normally
        # this class is without attribute so the code will never
        # use memory address to access attribute
        address = 0
      end
      (wn_object_addr = WNode.new(:insn, wnode)).c(:addr, value: address)
      # VERY IMPORTANT the wtype of this node is the Class name !!!
      wn_object_addr.wtype = WType.new(class_name.to_sym)
      wn_object_addr
    end

    def call(wnode, class_name, method_name, method_type)
      method = wnode.find_or_create_method(method_name, class_name, method_type)
      logger.debug "found method #{method.inspect}"
      (wn_call = WNode.new(:insn, wnode)).c(:call, func_name: method.wasm_name)
      wn_call.wtype = method.wtype
      wn_call
    end

    # self in an instance context is passed as the first argument
    # of a method call
    def _self(wnode)
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
      (wnb = WNode.new(:insn, wnode)).c(:block) 
      (wnl = WNode.new(:insn, wnb)).c(:loop) 
      (wnbi = WNode.new(:insn, wnl)).c(:br_if, label: wnb.label)
      return wnb,wnbi,wnl
    end

    # This is a post processing of the while
    # exp wnode because br_if requires to 
    # negate the original while condition
    def while_cond(wnode, wnode_cond_exp)
      wn_eqz = WNode.new(:insn, wnode)
      wn_eqz.c(:eqz, wtype: wnode_cond_exp.wtype)
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
      begin
        WType.leading(wnodes.map(&:wtype))
      rescue
        raise "#{wnodes.map(&:to_s)}"
      end
    end
  end
end