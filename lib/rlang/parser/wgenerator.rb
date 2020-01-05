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

  # Type cast order in decreading order of precedence
  TYPE_CAST_PRECEDENCE = [Type::F64, Type::F32, Type::I64, Type::I32]

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
    end

    def klass(wnode, const_node)
      wn = WNode.new(:class, wnode)
      wn.class_name = const_node.children.last
      WNode.root.class_wnodes << wn
      wn
    end

    def method(wnode, method)
      logger.debug("method #{method}")
      wn = WNode.new(:method, wnode)
      wn.method = method # must be set before calling func_name
      wn.wtype = method.wtype
      wn.c(:func, func_name: wn.func_name)
      logger.debug("wn.wtype #{wn.wtype}, wn.method #{wn.method}")
      wn
    end

    def params(wnode)
      wnode = wnode.method_wnode unless wnode.method?
      # use reverse to preserve proper param order
      wnode.margs.reverse.each do |marg|
        logger.debug("Prepending param #{marg}")
        wn = WNode.new(:insn, wnode, true)
        wn.wtype = marg.wtype
        wn.c(:param, name: marg.wasm_name)
      end
    end

    def result(wnode)
      unless wnode.wtype.nil?
        wn = WNode.new(:insn, wnode, true)
        wn.wtype = wnode.wtype
        wn.c(:result)      
      end
    end

    def locals(wnode)
      wnode = wnode.method_wnode unless wnode.method?
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
      WNode.new(:insn, wn).c(:addr, addr: const.address)
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
      WNode.new(:insn, wn).c(:addr, addr: cvar.address)
      wn
    end

    # Read class variable
    def cvar(wnode, cvar)
      (wn = WNode.new(:insn, wnode)).wtype = cvar.wtype
      wn.c(:load, wtype: cvar.wtype, var_name: cvar.wasm_name)
      WNode.new(:insn, wn).c(:addr, addr: cvar.address)
      wn
    end

    # Create the local variable storage node and
    # an empty expression node to populate later
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

    # wnode already contains the variable writer operation
    # and its last child is an empty wnode ready to populate
    # with the expression to compute
    def op_asgn(wnode, op_wtype, op)
      raise "Error: unknown operator #{op}" \
        unless ARITHMETIC_OPS_MAP.has_key? op
      (op_wnode = WNode.new(:insn, wnode)).wtype = op_wtype
      op_wnode.c(:operator, wtype: op_wtype, operator: ARITHMETIC_OPS_MAP[op])
      op_wnode
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

    # cast an expression to a different type
    # if same type do nothing
    # - wnode: the wnode to type cast 
    # - wtype: the wtype to cast wnode to
    # - signed: whether the cast wnode must be interpreted as a signed value
    #
    # TODO: simplify this complex method (possibly by using
    # a conversion table source type -> target type)
    def cast(wnode, wtype, signed=false)
      logger.debug "wnode: #{wnode}, wtype: #{wtype}"

      if wnode.wtype == Type::I32
        if wtype == Type::I64
          if (wnode.template == :const)
            # it's a const so don't do a cast but
            # simply change the const node wtype
            wnode.wtype = wtype
          else
            wn_cast_op = wnode.insert(:insn)
            wn_cast_op.wtype = wtype
            wn_cast_op.c(signed ? :extend_i32_s : :extend_i32_u , wtype: wtype)
          end
        elsif wtype == Type::I32
          # Do nothing
        else
          # TODO: float type cast
          raise "Error: don't know how to cast #{wnode.wtype.inspect} to #{wtype.inspect} in #{wnode}"
        end
      elsif wnode.wtype == Type::I64
        if wtype == Type::I32
          if (wnode.template == :const)
            # it's a const so don't do a cast but
            # simply change the const node wtype
            wnode.wtype = wtype
          else
            wn_cast_op = wnode.insert(:insn)
            wn_cast_op.wtype = wtype
            wn_cast_op.c(:wrap_i64, wtype: wtype)
          end
        elsif wtype == Type::I64
          # Do nothing
        else
          # TODO: float type cast
          raise "Error: don't know how to cast #{self.wtype.inspect} to #{wtype.inspect} in #{wnode}"
        end
      elsif wnode.wtype == Type::F32
        # TODO: float type cast
        raise "Error: don't know how to cast #{self.wtype.inspect} to #{wtype.inspect} in #{wnode}"
      elsif wnode.wtype == Type::F64
        raise "Error: don't know how to cast #{self.wtype.inspect} to #{wtype.inspect} in #{wnode}"
      end
      logger.debug "After type cast: wnode: #{wn_cast_op || wnode}, wtype: #{wtype}"
      wn_cast_op || wnode
    end

    # just create a wnode for the WASM operator
    # Do not set wtype or a code template yet,
    # wait until operands type is known (see
    # operands below)
    def operator(wnode, operator, wtype=:none)
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
    def operands(wnode, wnode_recv, wnode_args)
      raise "#{method_name} expects 0 or 1 argument (got #{wnode_args.count})" \
        if wnode_args.count > 1

      # First find out the wtype that has precedence
      wtype = self.class.leading_wtype(wnode_recv, *wnode_args)
      wnode.wtype = wtype
      logger.debug "leading type cast: #{wtype}"

      # Attach receiver and argument to the operator wnode
      # type casting them if necessary
      self.cast(wnode_recv, wtype).reparent_to(wnode)
      self.cast(wnode_args.first, wtype).reparent_to(wnode) unless wnode_args.empty?
    end

    def call(wnode, recv_node, method_name)
      if recv_node.type == :self
        class_name = wnode.class_name
      elsif recv_node.type == :const
        class_name = recv_node.children.last
      else
        raise "Error: can only call method on self or class objects (got #{recv_node})"
      end
      func_name = "$#{class_name}::#{method_name}"
      method = wnode.find_or_create_method(method_name, class_name)
      logger.debug "found method #{method.inspect}"
      (call_node = WNode.new(:insn, wnode)).c(:call, func_name: func_name)
      call_node.wtype = method.wtype
      call_node
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
    end

    def next(wnode)
      # look for loop wnode upper in the tree
      # branch to that label
      (wn = WNode.new(:insn, wnode)).c(:br, label: wnode.loop_wnode.label)
    end
=begin
    def and(wnode, wnode_cond1_exp, wnode_cond2_exp)
      send(wnode, :&&, wnode_recv, wnode_args)
      wtype = self.class.leading_wtype(wnode_cond1_exp, wnode_cond2_exp)
      wn = WNode.new(:insn, wnode)
      wn.wtype = wtype; wn.c(:operator, wtype: wtype, operator: :and)
      self.cast(wnode_cond1_exp, wtype).reparent_to(wn)
      self.cast(wnode_cond2_exp, wtype).reparent_to(wn)
      wn
    end

    def or(wnode, wnode_cond1_exp, wnode_cond2_exp)
      wtype = self.class.leading_wtype(wnode_cond1_exp, wnode_cond2_exp)
      wn = WNode.new(:insn, wnode)
      wn.wtype = wtype; wn.c(:operator, wtype: wtype, operator: :or)
      self.cast(wnode_cond1_exp, wtype).reparent_to(wn)
      self.cast(wnode_cond2_exp, wtype).reparent_to(wn)
      wn
    end
=end
    def not(wnode)
    end

    private
    # Determine which wasm type has precedence among
    # all wnodes
    def self.leading_wtype(*wnodes)
      TYPE_CAST_PRECEDENCE[
        wnodes.map(&:wtype).map {|wt| TYPE_CAST_PRECEDENCE.index(wt)}.sort.first
      ]
    end
  end
end