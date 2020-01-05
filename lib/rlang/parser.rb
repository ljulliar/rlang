# Rubinius WebAssembly VM
# Copyright (c) 2019, Laurent Julliard and contributors
# All rights reserved.

# Rlang parser
# Rlang is a subset of the Ruby language that can be transpiled
# to WAT and then compiled to WASM. The Rubinius WASM virtual
# machine is written in Rlang.

# TODO: write a short documentation about what subset of Ruby is
# supported in Rlang

require 'parser/current'
require 'pathname'
require_relative '../utils/log'
require_relative './parser/wtree'
require_relative './parser/wnode'
require_relative './parser/cvar'
require_relative './parser/lvar'
require_relative './parser/marg'
require_relative './parser/global'
require_relative './parser/data'
require_relative './parser/wgenerator'

module Rlang::Parser
  class Parser

    include Log

    ARITHMETIC_OPS = [:+, :-, :*, :/, :%, :&, :|, :^, :>>, :<<]
    RELATIONAL_OPS = [:==, :!=, :>, :<, :>=, :<=, :'>s', :'<s', :'>=s', :'>=s']
    UNARY_OPS = [:'!']

    # Type cast order in decreading order of precedence
    TYPE_CAST_PRECEDENCE = [Type::F64, Type::F32, Type::I64, Type::I32]

    # WARNING!! THIS IS A **VERY** NASTY HACK PRETENDING
    # THAT THIS int VALUE means NIL. It's totally unsafe 
    # of course as an expression could end up evaluating
    # to this value and not be nil at all. But I'm using
    # it for now in the xxxx_with_result_type variants of
    # some parsing methods (if, while,...)
    NIL = 999999999

    # export toggle for method declaration
    @@export = false


    attr_accessor :wgenerator, :source, :config

    def initialize(wgenerator)
      @wgenerator = wgenerator
      # LIFO of parsed files (stacked by require)
      @requires = []
      config_init
    end

    def config_init
      @config = {}
      @config[:LOADED_FEATURES] = []
      @config[:LOAD_PATH] = ''
      @config[:__FILE__] = ''
    end

    # Note : this method can be called recursively
    # through require statements
    def parse_file(file)
      raise "parse_file only acccepts absolute path (got #{file})" \
        unless Pathname.new(file).absolute? || file.nil?
      # Already parsed. Ignore.
      if self.config[:LOADED_FEATURES].include? file
        logger.debug "File already loaded."
        return
      end

      # Set file currently parsed
      # Maintain a list of embedded require's
      @requires << (@config[:__FILE__] = file) if file

      # Parse file
      source = file ? File.open(file) : STDIN
      self.parse(File.read(source) )
      # Ff parsing went to completion then add this
      # file to the list of successfully loaded files
      (@config[:LOADED_FEATURES] ||= []) << file if file
      # and go back to previously parsed file
      @config[:__FILE__] = @requires.pop if file
    end

    def parse(source)
      ast = ::Parser::CurrentRuby.parse(source)
      parse_node(ast, @wgenerator.root) if ast
    end

    # Parse Ruby AST node and generate WAT
    # code as a child of wnode
    # - node: the Ruby AST node to parse
    # - wnode: the parent wnode for the generated WAT code
    # - keep_eval: whether to keep the value of the evaluated
    #   WAT expression on stock or not
    def parse_node(node, wnode, keep_eval=true)
      logger.debug "\n------------------------\n" + 
        "Parsing node: #{node}, wnode: #{wnode}, keep_eval: #{keep_eval}"

      case node.type
      when :class
        parse_class(node, wnode)

      when :defs
        parse_defs(node, wnode)

      when :def
        raise "instance method definition not supported"

      when :begin
        parse_begin(node, wnode, keep_eval)

      when :casgn
        parse_casgn(node, wnode, keep_eval)

      when :cvasgn
        parse_cvasgn(node, wnode, keep_eval)

      when :gvasgn
        parse_gvasgn(node, wnode, keep_eval)

      when :lvasgn
        parse_lvasgn(node, wnode, keep_eval)

      when :op_asgn
        parse_op_asgn(node, wnode, keep_eval)

      when :lvar
        parse_lvar(node, wnode, keep_eval)

      when :cvar
        parse_cvar(node, wnode, keep_eval)

      when :gvar
        parse_gvar(node, wnode, keep_eval)

      when :int
        parse_int(node, wnode, keep_eval)
      
      when :float
        raise "float instructions not supported"
        #parse_float(node, wnode, keep_eval)

      when :nil
        raise "nil not supported"

      when :const
        parse_const(node, wnode, keep_eval)

      when :send
        parse_send(node, wnode, keep_eval)

      when :return
        parse_return(node, wnode, keep_eval)
      
      when :if
        #parse_if_with_result_type(node, wnode, keep_eval)
        parse_if_without_result_type(node, wnode, keep_eval)
      
      when :while
        #parse_while_with_result_type(node, wnode, keep_eval)
        parse_while_without_result_type(node, wnode, keep_eval)
      
      when :until
        #parse_while_with_result_type(node, wnode, keep_eval)
        parse_while_without_result_type(node, wnode, keep_eval)
      
      when :break
        parse_break(node, wnode, keep_eval)

      when :next
        parse_next(node, wnode, keep_eval)

      when :or, :and
        parse_logical_op(node, wnode, keep_eval)

      else
        raise "Unknown node type: #{node.type} => #{node}"
      end
    end

    def parse_begin(node, wnode, keep_eval)
      child_count = node.children.count
      wn = nil
      node.children.each_with_index do |n, idx|
        # A begin block always evaluates to the value of
        # its last child except if  this begin node
        # is a child of a method definition and a 'result' directive
        # was issued to say result of this method must be :none
        if (idx == child_count-1)
          if wnode.type == :method
            local_keep_eval = !wnode.wtype.nil?
          else
            local_keep_eval = keep_eval
          end
        else
          local_keep_eval = false
        end
        logger.debug "node idx: #{idx}/#{child_count}, wnode type: #{wnode.type}, keep_eval: #{keep_eval}, local_keep_eval: #{local_keep_eval}"
        wn = parse_node(n, wnode, local_keep_eval)
      end
      return wn # return last wnode
    end

    # Example:
    # class Stack
    #  ... body ...
    # end
    # -----
    # [s(:const, nil, :Stack), nil, s(:begin ... body.... )]
    #
    def parse_class(node, wnode)
      const_node = node.children.first
      body_node = node.children.last
      raise "expecting a constant for class name (got #{const_node})" unless const_node.type == :const
      wn_class = @wgenerator.klass(wnode, const_node)
      parse_node(body_node, wn_class) if body_node
      return wn_class
    end

    # TODO: the code for op_asgn is quite murky but I thought
    # we would use quite often so I implemented it. We could do
    # without it though..
    #
    # Example (local var)
    #   arg1 *= 20
    # ---
    # (op-asgn
    #   (lvasgn :arg1)
    #   :* 
    #   (int 20)) )
    #
    # Example (class var)
    # @@stack_ptr -= nbytes
    # ---
    # s(:op_asgn,
    #    s(:cvasgn, :@@stack_ptr), :-, s(:lvar, :nbytes))
    #
    # Example (global var)
    # $MYGLOBAL -= nbytes
    # ---
    # s(:op_asgn,
    #    s(:gvasgn, :$MYGLOBAL), :-, s(:lvar, :nbytes))
    #
    # **** DEPRECATED FORM OF GLOBALS *****
    # Example (Global)
    # Global[:$DEBUG] += 1
    # ---
    # (op-asgn
    #   (send
    #     (const nil :Global) :[] (sym :$DEBUG))
    #     :+
    #     (int 1)))
    #
    def parse_op_asgn(node, wnode, keep_eval)
      logger.debug "wnode: #{wnode}, keep_eval: #{keep_eval}"

      case node.children.first.type
      # Global variable case
      when :gvasgn
      var_asgn_node, op, exp_node = *node.children
      var_name = var_asgn_node.children.last

      # parse the variable setting part
      # Note: this will also create the variable setting
      # wnode as a child of wnode
      wn_var_set = parse_node(var_asgn_node, wnode, keep_eval)
      gvar = Global.find(var_name)
      raise "Unknown global variable #{var_name}" unless gvar

      # Create the operator node (infer operator type from variable)
      op_wnode = @wgenerator.op_asgn(wn_var_set, gvar.wtype, op)
      # Create the var getter node as a child of operator node
      @wgenerator.gvar(op_wnode, gvar)

        # Class variable case
      when :cvasgn
        var_asgn_node, op, exp_node = *node.children
        var_name = var_asgn_node.children.last

        # parse the variable setting part
        # Note: this will also create the variable setting
        # wnode as a child of wnode
        wn_var_set = parse_node(var_asgn_node, wnode, keep_eval)
        cvar = wnode.find_cvar(var_name)
        raise "Unknown class variable #{var_name}" unless cvar

        # Create the operator node (infer operator type from variable)
        op_wnode = @wgenerator.op_asgn(wn_var_set, cvar.wtype, op)
        # Create the var getter node as a child of operator node
        @wgenerator.cvar(op_wnode, cvar)
      
      # Local variable case
      when :lvasgn
        var_asgn_node, op, exp_node = *node.children
        var_name = var_asgn_node.children.last

        # parse the variable setter node
        # Note: this will also create the variable setting
        # wnode as a child of wnode
        wn_var_set = parse_node(var_asgn_node, wnode, keep_eval)
        #p var_asgn_node; exit
        lvar = wnode.find_lvar(var_name) || wnode.find_marg(var_name)
        raise "Unknown local variable #{var_name}" unless lvar

        # Create the operator node (infer operator type from variable)
        op_wnode = @wgenerator.op_asgn(wn_var_set, lvar.wtype, op)
        # Create the var getter node as a child of operator node
        @wgenerator.lvar(op_wnode, lvar)

        
=begin
      # **** DEPRECATED FORM OF GLOBALS *****
      # Global[] case
      when :send
        #p node.children
        var_asgn_node, op, exp_node = *node.children
        #p node.children.first.children
        const_node, gop, gvar_key_node = *var_asgn_node.children
        #p const_node, gvar_key_node, gvar_key_node.type
        # TODO: expand to support op_asgn on any class receiver
        # e.g.   ClassA.my_attr += 15
        unless (const_node.type == :const && const_node.children.last == :Global && gvar_key_node.type == :sym)
          raise "op_asgn only supported for Global class. Was #{var_asgn_node}"
        end
        #p var_asgn_node; exit

        # create gvar setter node
        gv_name = gvar_key_node.children.last
        raise "Global #{gv_name} not initialized" \
          unless (gvar = Global.find(gv_name))
        wn_var_set = @wgenerator.gvasgn(wnode, gvar)
        # Create the operator node (infer operator type from variable)
        op_wnode = @wgenerator.op_asgn(wn_var_set, gvar.wtype, op)
        # Create the var getter node as a child of operator node
        @wgenerator.gvar(op_wnode, gvar)
        # to mimic Ruby push the variable value on stack if needed
        @wgenerator.gvar(wnode, gvar) if keep_eval
=end
      else
        raise "op_asgn not supported for variable type #{var_asgn_node}"
      end

      # Finally, parse the expression node and make it a node
      # of the second child of the operator node
      # Last evaluated value must be kept of course
      parse_node(exp_node, op_wnode, true)

      # No need to drop last evaluated value even if
      # asked to because var assignment never leaves
      # any value on the WASM stack
      #@wgenerator.drop(wnode) unless keep_eval
      return wn_var_set
    end

    # Example
    #   MYCONST = 2000
    # ---
    # (casgn nil :MYCONST
    #   (int 2000))
    def parse_casgn(node, wnode, keep_eval)
      class_name_node, constant_name, exp_node = *node.children
      raise "dynamic constant assignment" unless wnode.in_class_scope?
      raise "constant initialization can only take a number" unless exp_node.type == :int

      unless class_name_node.nil?
        raise "constant assignment with class path not supported (got #{class_name_node})"
      end
      if wnode.find_const(constant_name)
        raise "constant #{constant_name} already initialized"
      end

      # TODO: const are I32 hardcoded. Must find a way to 
      # initialize I64 constant
      value = exp_node.children.last
      const = wnode.create_const(constant_name, nil, value, Type::I32)

      wn_casgn = @wgenerator.casgn(wnode, const)
      return wn_casgn
    end

    # Example
    #   $MYGLOBAL = 2000
    # ---
    # (gvasgn :MYGLOBAL
    #   (int 2000))
    #
    # Example with type cast
    # $MYGLOBAL = 2000.to_i64
    # ---
    # (gvasgn :MYGLOBAL
    #   (send (int 2000) :to_i64))
    def parse_gvasgn(node, wnode, keep_eval)
      gv_name, exp_node = *node.children
      gvar = Global.find(gv_name)

      if wnode.in_method_scope?
        # if exp_node is nil then this is the form of 
        # :gvasgn that comes from op_asgn
        if exp_node
          if gvar.nil?
            # first gvar occurence
            # type cast the gvar to the wtype of the expression
            gvar = Global.new(gv_name)
            wn_gvasgn = @wgenerator.gvasgn(wnode, gvar)
            exp_wnode = parse_node(exp_node, wn_gvasgn)
            gvar.wtype = exp_wnode.wtype
          else
            # if gvar already exists then type cast the 
            # expression to the wtype of the existing gvar
            wn_gvasgn = @wgenerator.gvasgn(wnode, gvar)
            exp_wnode = parse_node(exp_node, wn_gvasgn)
            @wgenerator.cast(exp_wnode, gvar.wtype, false)
          end
        else
          raise "Global variable #{cv_name} not declared before" unless gvar
          wn_gvasgn = @wgenerator.gvasgn(wnode, gvar)
        end
        # to mimic Ruby push the variable value on stack if needed
        @wgenerator.gvar(wnode, gvar) if keep_eval
        return wn_gvasgn
      else
        # If we are at root or in class scope
        # then it is a global variable initialization
        raise "Global #{gv_name} already declared" if gvar
        raise "Global op_asgn can only happen in method scope" unless exp_node
        # In the class or root scope 
        # it can only be a Global var **declaration**
        # In this case the expression has to reduce
        # to a const wnode that can be used as value
        # in the declaration (so it could for instance
        # Global[:label] = 10 or Global[:label] = 10.to_i64)
        exp_wnode = parse_node(exp_node, nil)
        raise "Global initializer can only be a straight number" \
          unless exp_wnode.template == :const
        gvar = Global.new(gv_name, exp_wnode.wtype, exp_wnode.wargs[:value])
      end
    end

    # Example
    # @@stack_ptr = 10 + nbytes
    # ---
    # s(:cvasgn, :@@stack_ptr, s(:send, s(:int, 10), :+, s(:lvar, :nbytes)))
    def parse_cvasgn(node, wnode, keep_eval)
      cv_name, exp_node = *node.children
      cvar = wnode.find_cvar(cv_name)

      if wnode.in_method_scope?      
        # if exp_node is nil then this is the form of 
        # :cvasgn that comes from op_asgn
        if exp_node
          if cvar.nil?
            # first cvar occurence
            # type cast the cvar to the wtype of the expression
            cvar = wnode.create_cvar(cv_name)
            wn_cvasgn = @wgenerator.cvasgn(wnode, cvar)
            exp_wnode = parse_node(exp_node, wn_cvasgn)
            cvar.wtype = exp_wnode.wtype
          else
            # if cvar already exists then type cast the 
            # expression to the wtype of the existing cvar
            wn_cvasgn = @wgenerator.cvasgn(wnode, cvar)
            exp_wnode = parse_node(exp_node, wn_cvasgn)
            @wgenerator.cast(exp_wnode, cvar.wtype, false)
          end
        else
          raise "Class variable #{cv_name} not declared before" unless cvar
          wn_cvasgn = @wgenerator.cvasgn(wnode, cvar)
        end
        # to mimic Ruby push the variable value on stack if needed
        @wgenerator.cvar(wnode, cvar) if keep_eval
        return wn_cvasgn

      elsif wnode.in_class_scope?
        # If we are in class scope
        # then it is a class variable initialization
        raise "Class variable #{cv_name} already declared" if cvar
        raise "Class variable op_asgn can only happen in method scope" unless exp_node
        exp_wnode = parse_node(exp_node, nil)
        raise "Class variable initializer can only be a straight number" \
          unless exp_wnode.template == :const
        cvar = wnode.create_cvar(cv_name, exp_wnode.wargs[:value], exp_wnode.wtype)
        logger.debug "Class variable #{cv_name} init with value #{cvar.value} and wtype #{cvar.wtype}"
      else
        raise "Class variable can only be defined in method or class scope"
      end
    end

    # Regular Example
    # var1 = @@stack_ptr + nbytes
    # ---
    # s(:lvasgn, :var1, s(:send, s(:cvar, :@@stack_ptr), :+, s(:lvar, :nbytes)))
    #
    # Example coming from an op_asgn node
    # arg1 += 2
    # ---
    # s(s(lvasgn, :arg1), :+, s(int 2)))

    def parse_lvasgn(node, wnode, keep_eval)
      lv_name, exp_node = *node.children
      lvar = wnode.find_lvar(lv_name) || wnode.find_marg(lv_name)

      logger.debug "Assign to #{lv_name}, exp_node: #{exp_node}, keep_eval: #{keep_eval}"
      logger.debug "lvar found: #{lvar}"

      # if exp_node is nil then this is the form of 
      # :lvasgn that comes from op_asgn
      if exp_node
        if lvar.nil?
          # first lvar occurence
          # type cast the lvar to the wtype of the expression
          lvar = wnode.create_lvar(lv_name)
          wn_lvasgn = @wgenerator.lvasgn(wnode, lvar)
          exp_wnode = parse_node(exp_node, wn_lvasgn)
          lvar.wtype = exp_wnode.wtype
        else
          # if cvar already exists then type cast the 
          # expression to the wtype of the existing cvar
          wn_lvasgn = @wgenerator.lvasgn(wnode, lvar)
          exp_wnode = parse_node(exp_node, wn_lvasgn)
          @wgenerator.cast(exp_wnode, lvar.wtype, false)
        end
      else
        raise "Local variable #{cv_name} not declared before" unless lvar
        wn_lvasgn = @wgenerator.lvasgn(wnode, lvar)
      end
      # to mimic Ruby push the variable value on stack if needed
      @wgenerator.lvar(wnode, lvar) if keep_eval
      return wn_lvasgn
    end

    # Example
    # ... $MYGLOBAL
    # ---
    # ... s(:gvar, :$MYGLOBAL)
    def parse_gvar(node, wnode, keep_eval)
      gv_name, = *node.children
      gvar = Global.find(gv_name)
      raise "Unknown Global variable #{gv_name}" unless gvar
      wn_gvar = @wgenerator.gvar(wnode, gvar)
      # Drop last evaluated result if asked to
      @wgenerator.drop(wnode) unless keep_eval
      return wn_gvar
    end

    # Example
    # ... @@stack_ptr
    # ---
    # ... s(:cvar, :@@stack_ptr)
    def parse_cvar(node, wnode, keep_eval)
      raise "Class variable can only be accessed in method scope" \
        unless wnode.in_method_scope?
      cv_name, = *node.children
      if (cvar = wnode.find_cvar(cv_name))
        wn_cvar = @wgenerator.cvar(wnode, cvar)
      else
        raise "unknown class variable #{cv_name}"
      end
      # Drop last evaluated result if asked to
      @wgenerator.drop(wnode) unless keep_eval
      return wn_cvar
    end

    # Example
    # ... nbytes
    # ---
    # ... s(:lvar, :nbytes)
    def parse_lvar(node, wnode, keep_eval)
      logger.debug("node: #{node}, wnode: #{wnode}, keep_eval: #{keep_eval}")

      lv_name, = *node.children
      if (lvar = wnode.find_lvar(lv_name) || wnode.find_marg(lv_name))
        wn_lvar = @wgenerator.lvar(wnode, lvar)
      else
        raise "unknown local variable #{lv_name}"
      end
      logger.debug("wnode: #{wnode}")
      # Drop last evaluated result if asked to 
      @wgenerator.drop(wnode) unless keep_eval
      return wn_lvar
    end

    def parse_int(node, wnode, keep_eval)
      value, = *node.children
      # Match the int type with the node of the parent type
      wtype = wnode&.wtype || Type::DEFAULT_TYPE
      logger.debug "wnode #{wnode} wtype: #{wtype} keep_eval:#{keep_eval}"

      wn_int = @wgenerator.int(wnode, wtype, value)
      # Drop last evaluated result if asked to
      @wgenerator.drop(wnode) unless keep_eval

      logger.debug "wnode:#{wnode} wtype:#{wtype} keep_eval:#{keep_eval}"
      return wn_int
    end

    # Example
    # TestA::C::MYCONST
    # -------
    # (const (const (const nil :TESTA) :C) :MYCONST))
    def parse_const(node, wnode, keep_eval)
      const_path = []
      n = node
      while n
        logger.debug "adding #{n.children.last} to constant path"
        const_path.unshift(n.children.last)
        n = n.children.first
      end
      full_const_name = const_path.join('::')
      if const_path.size == 1
        class_name = wnode.class_name
        const_name = const_path.first
      elsif const_path.size == 2
        class_name, const_name = *const_path
      else
        raise "only constant of the form X or X::Y is supported (got #{full_const_name}"
      end

      unless (const = wnode.find_const(const_name, class_name))
        raise "unknown constant #{full_const_name}"
      end
      wn_const = @wgenerator.const(wnode, const)

      # Drop last evaluated result if asked to
      @wgenerator.drop(wnode) unless keep_eval
      return wn_const
    end

    # method arguments
    def parse_args(node, wnode)
      # collect method arguments
      node.children.each do |arg_node|
        raise "only regular method argument is supported (got #{arg_node.type})" if arg_node.type != :arg
        # keep track of method arguments. Do not generate wasm code yet
        # as 'arg' directives may later affect argument types (see parse_send)
        wnode.create_marg(arg_node.children.last)
      end
    end

    # method definition
    # Example
    # s(:defs,
    #    s(:self), :push,
    #    s(:args,
    #      s(:arg, :value)),... )
    #-----
    # def self.push(value)
    #   ...
    # end
    def parse_defs(node, wnode)
      logger.debug "node: #{node}\nwnode: #{wnode}"
      recv_node, method_name, arg_nodes, body_node = *node.children
      raise "only class method is supported. Wrong receiver at #{recv_node.loc.expression}" if recv_node.type != :self
      logger.debug "recv_node: #{recv_node}\nmethod_name: #{method_name}"

      # create corresponding func node
      method = wnode.find_or_create_method(method_name)
      method.export! if @@export
      logger.debug "Method object : #{method.inspect}"
      wn_method = @wgenerator.method(wnode, method)
      # collect method arguments
      parse_args(arg_nodes, wn_method)
      # method body -- A method evaluates to its last 
      # computed value unless a result :nil directive
      # is specified
      logger.debug "method_name: #{method_name}, wtype: #{wn_method.wtype}"
      parse_node(body_node, wn_method)

      # Now that we have parsed the whole method we can 
      # prepend locals, result and method args to the
      # method wnode (in that order)
      @wgenerator.locals(wn_method)
      @wgenerator.result(wn_method)
      @wgenerator.params(wn_method)
      logger.debug "Full method wnode: #{wn_method}"
      # reset export toggle
      @@export = false
      return wn_method
    end

    def parse_require(wnode, file)
      logger.debug "File required: #{file}"
      extensions = ['', '.wat', '.rb']
      full_path_file = nil
      if Pathname.new(file).absolute?
        logger.debug "Absolute path detected"
        extensions.each do |ext|
          full_path_file = file+ext
          break if File.exist?(full_path_file)
        end
      else
        case file
        when /^\./
          # If file starts with . then look for file in pwd
          load_path = [Dir.pwd]
        when /^rlang/
          # If it starts with rlang then look for it in the 
          # installed rlang gem in addition to load path
          load_path = self.config[:LOAD_PATH] + Gem.default_path
        else
          load_path = self.config[:LOAD_PATH]
          load_path = [Dir.pwd] if self.config[:LOAD_PATH].empty?
        end
        logger.debug "load_path: #{load_path} for file #{file}"

        # Now try each possible extension foreach possible
        # directory in the load path
        load_path.each do |dir|
          break unless extensions.each do |ext|
            full_path_file = File.expand_path(File.join(dir, file+ext))
            if File.file?(full_path_file)
              logger.debug "Found required file: #{full_path_file}"; break
            end
          end
        end
      end
      raise LoadError, "no such file to load: #{file}" unless full_path_file

      # Now load the file 
      if File.extname(full_path_file) == '.wat'
        wat_code = File.read(full_path_file)
        @wgenerator.inline(wnode, wat_code)
      else
        parse_file(full_path_file)
      end
    end

    def parse_require_relative(wnode, file)
      logger.debug "Currently parsed file: #{self.config[:__FILE__]}"
      full_path_file = File.expand_path(file, File.dirname(self.config[:__FILE__]))
      parse_require(wnode, full_path_file)
    end

    # s(:send, nil, :method_name, ...
    def parse_send(node, wnode, keep_eval)
      recv_node = node.children[0]
      method_name = node.children[1]
      logger.debug "recv_node #{recv_node}, method_name : #{method_name}"

      # Directive to require a file
      # Example
      # (send nil :require
      #   (str "test5"))
      if recv_node.nil? && method_name == :require
        raise "require must be used at root level" \
          unless wnode.in_root_scope?
        file_node = node.children.last
        raise "require only accepts a string argument (got #{file_node})" \
          unless file_node.type == :str
        parse_require(wnode, file_node.children.last)
        return
      end

      # Directive to require_a file relative to
      # current file
      # Example
      # (send nil :require_relative
      #   (str "test5"))
      if recv_node.nil? && method_name == :require_relative
        raise "require_relative must be used at root level" \
          unless wnode.in_root_scope?
        file_node = node.children.last
        raise "require only accepts a string argument (got #{file_node})" \
          unless file_node.type == :str
        parse_require_relative(wnode, file_node.children.last)
        return
      end

      # Directive to declare the current method
      # in the WASM exports
      if recv_node.nil? && method_name == :export
        raise "export must be used in class scope" \
          unless wnode.in_class_scope?
        @@export = true
        return
      end

      # Directive to define local variable type
      # this must be processed at compile time
      if recv_node.nil? && method_name == :local
        # if method name is :local then it is
        # a type definition for a local variable
        # local :value, :I64
        # ---------
        # s(:send, nil, :local,
        #   s(:sym, :value),
        #   s(:sym, :I64))
        raise "local variable must be a symbol (got #{node.children[2]})" unless node.children[2].type == :sym
        lv_name, = *node.children[2]
        lv_type, = *node.children[3]
        lvar = wnode.find_or_create_lvar(lv_name)
        lvar.wtype = lv_type
        return
      end

      # Directive to define method argument type
      # this must be processed at compile time
      if  recv_node.nil? && method_name == :arg
        # if method name is :arg then it is
        # a type definition for a method argument
        # arg :value, :I64
        # ---------
        # s(:send, nil, :arg,
        #   s(:sym, :value),
        #   s(:sym, :I64))
        arg_name, = *node.children[2]
        arg_type, = *node.children[3]
        marg = wnode.find_marg(arg_name)
        raise "couldn't find method argument #{arg_name}" unless marg
        marg.wtype = arg_type
        return
      end

      # Directive to define method return type
      # in the method itself
      # this must be processed at compile time
      # Supported types : :I32, :I64, :none 
      # (:nil means no value is returned)
      # 
      # Example
      # ret :I64
      # ---------
      # s(:send, nil, :result,
      #   s(:sym, :I64))
      if recv_node.nil? && method_name == :result && wnode.in_method_scope?
        result_type, = *node.children[2]
        legit_types = [:I32, :I64, :none]
        unless legit_types.include? result_type
          raise "result type must be one of #{legit_types} (got #{result_type.inspect})"
        end
        wnode.method_wnode.wtype = result_type
        logger.debug "result_type #{result_type} wnode.method_wnode.wtype #{wnode.method_wnode.wtype.inspect}"
        return
      end

      # Directive to define method return type
      # at the class level. This allows to declare
      # a method type before the method is parsed
      # this must be processed at compile time
      # Supported types : :I32, :I64, :none 
      # (:nil means no value is returned)
      #
      # Example
      # result :class_name, :method_name, :I64
      # ---------
      # s(:send, nil, :result,
      #   s(:sym, :class_name),
      #   s(:sym, :method_name),
      #   s(:sym, :I64))
      if recv_node.nil? &&  method_name == :result && wnode.in_class_scope?
        cn_name,  = *node.children[2]
        mn_name,  = *node.children[3]
        result_type, = *node.children[4]
        legit_types = [:I32, :I64, :none]
        unless legit_types.include? result_type
          raise "method type must be one of #{legit_types} (got #{result_type.inspect})"
        end
        (mwn = wnode.find_or_create_method(mn_name, cn_name)).wtype = result_type
        logger.debug "result_type #{mwn.wtype} for method #{mwn.name}"
        return
      end

      # Directive to inline WAT / Ruby code
      # the wat entry is used when the Rlang code is
      # comiled to WAT code. The Ruby entry is used 
      # when the rlang code is simulated in plain Ruby
      # **CAUTION** the inline code is supposed to always
      # leave a value on the stack
      # Example
      # inline wat: '(call_indirect (type $insn_t) 
      #                 (local.get $state) 
      #                 (local.get $cf) 
      #                 (local.get $opcodes) 
      #                 (local.get $opcode) ;; instruction function pointer
      #               )',
      #        ruby: 'call_indirect(state, cf, opcodes, opcode)'
      #
      # ---------
      # (send, nil, :inline,
      #   (hash
      #     (pair
      #       (sym :wat)
      #       (dstr
      #         (str "(call_indirect (type $insn_t) \n")
      #         (str "...")
      #           ...))
      #     (pair)
      #       (sym :wtype)
      #       (sym :I64)
      #     (pair
      #       (sym :ruby)
      #       (str "call_indirect(state, cf, opcodes, opcode)"))
      #  
      if recv_node.nil? &&  method_name == :inline
        raise "inline can only happen in a method bodyor at root" \
          unless wnode.in_method_scope? || wnode.in_root_scope?
        hash_node = node.children.last
        raise "inline expect a hash argument (got #{hash_node.type}" \
          unless hash_node.type == :hash

        # Find the :wat entry in hash
        logger.debug "Hash node: #{hash_node} "
        wat_node = hash_node.children. \
          find {|pair| sym_node, = *pair.children; sym_node.children.last == :wat}
        raise "inline has no wat: hash entry" unless wat_node

        # Find the :wtype entry in hash if any
        wtype_node = hash_node.children. \
          find {|pair| sym_node, = *pair.children; sym_node.children.last == :wtype}
        if wtype_node
          wtype = wtype_node.children.last.children.last
        else
          wtype = :I32
        end
        legit_types = [:I32, :I64, :none]
        unless legit_types.include? wtype
          raise "inline type must be one of #{legit_types} (got #{wtype.inspect})"
        end
        raise "inline has no wat: hash entry" unless wat_node

        # Now extract the WAT code itself
        wcode_node = wat_node.children.last
        if wcode_node.type == :dstr
          # iterate over str children
          wat_code = wcode_node.children.collect {|n| n.children.last}.join('')
        elsif wcode_node.type == :str
          wat_code = wcode_node.children.last
        else
          raise "inline WAT code must be a string (got #{wcode_node})"
        end
        wn_inline = @wgenerator.inline(wnode, wat_code, wtype)
        # Drop last evaluated result if asked to
        @wgenerator.drop(wnode) unless keep_eval
        return wn_inline
      end

=begin
      # **** DEPRECATED - RUBY GLOBALS ARE USED INSTEAD ****
      # Special case : Global class calls
      # Example
      # Global[:$TEST] = 0
      # ---------
      # s(:send,
      #   s(:const, nil, :Global), :[]=,
      #   s(:sym, :$TEST),
      #   s(:int, 0)
      # )
      if recv_node.type == :const  && recv_node.children.last == :Global
        if (gvar_key_node = node.children[2]).type == :sym
          gv_name = gvar_key_node.children.last
          gvar = Global.find(gv_name)
          first_time_gvar = gvar.nil?
        else
          raise "Global key must be a symbol (got #{key_node}"
        end

        case method_name
        when :[]
          raise "unknown Global variable #{gv_name}" unless gvar
          wn_gvar = @wgenerator.gvar(wnode, gvar)
        when :[]=
          exp_node = node.children[3]
          if wnode.in_method_scope?
            # it's a Global var computation
            # if first time gvar then gvar type is the type
            # of the expression. Else cast exp to gvar type
            if first_time_gvar
              gvar = Global.new(gv_name)
              wn_gvasgn = @wgenerator.gvasgn(wnode, gvar)
              exp_wnode = parse_node(exp_node, wn_gvasgn)
              gvar.wtype = exp_wnode.wtype
            else
              wn_gvasgn = @wgenerator.gvasgn(wnode, gvar)
              exp_wnode = parse_node(exp_node, wn_gvasgn)
              @wgenerator.cast(exp_wnode, gvar.wtype, false)
            end
            # Mimic Ruby by pushing global var value on stack if needed
            @wgenerator.gvar(wnode, gvar) if keep_eval
          else
            # In the class or root scope 
            # it can only be a Global var **declaration**
            # In this case the expression has to reduce
            # to a const wnode that can be used as value
            # in the declaration (so it could for instance
            # Global[:label] = 10 or Global[:label] = 10.to_i64)
            raise "Global #{gv_name} already declared" unless first_time_gvar
            exp_wnode = parse_node(exp_node, nil)
            raise "Global initializer can only be a straight number" \
              unless exp_wnode.template == :const
            gvar = Global.new(gv_name, exp_wnode.wtype, exp_wnode.wargs[:value])
          end

        when :new
          # TODO
          # For now a Global is created the first time it's used
          raise "Global.new not yet supported"
        else
          raise "Unsupported method for Global : #{method_name}"
        end
        # Drop last evaluated result if asked to
        @wgenerator.drop(wnode) unless keep_eval
        return wn_gvar || wn_gvasgn
      end
=end

      # Special case : DAta initializers
      #
      # Example (setting DAta address)
      # DAta.current_address = 0
      # ---------
      # (send
      #   (const nil :DAta) :current_address=
      #   (int 0))
      #
      # Example (setting DAta alignment)
      # DAta.align(8)
      # ---------
      # (send
      #   (const nil :DAta) :align
      #   (int 8))
      #
      # Example (value is an i32)
      # DAta[:an_I32] = 3200
      # ---------
      # (send
      #  (const nil :DAta) :[]=
      #  (sym :an_I32)
      #  (int 32000))
      # )
      #
      # Example (value is an i64)
      # DAta[:an_I64] = 3200.to_i64
      # ---------
      # (send
      #  (const nil :DAta) :[]=
      #  (sym :an_I64)
      #  (send
      #    (int 32000) :to_ixx))
      # )
      # 
      # Example (value is a String)
      # DAta[:a_string] = "My\tLitte\tRlang\x00"
      # ---------
      # (send
      #   (const nil :Data) :[]=
      #   (sym :a_string)
      #   (str "My\tLitte\tRlang\u0000"))
      #
      # Example (value is a data address)
      # DAta[:an_address] = DAta[:a_string]
      # ---------
      # (send
      #   (const nil :DAta) :[]=
      #  (sym :an_address)
      #  (send
      #    (const nil :DAta) :[]
      #    (sym :a_string)))
      #
      # Example (value is an array)
      # Data[:an_array] = [ Data[:an_I64], 5, 257, "A string\n"]
      # ---------
      # (send
      #   (const nil :Data) :[]=
      #   (sym :an_array)
      #   (array
      #     (send
      #       (const nil :Data) :[]
      #       (sym :an_I64))
      #     (int 5)
      #    (int 257)
      #    (str "A string\n")))
      #

      if recv_node.type == :const  && recv_node.children.last == :DAta
        case method_name
        when :current_address=
          value_node = node.children[2]
          raise "DAta address must be an integer" unless value_node.type == :int
          DAta.current_address = value_node.children.last
        when :align
          value_node = node.children[2]
          raise "DAta alignment argument must be an integer" unless value_node.type == :int
          DAta.align(value_node.children.last)
        when :[]=
          if (data_label_node = node.children[2]).type == :sym
            label = data_label_node.children.last
          else
            raise "Data label must be a symbol (got #{data_label_node}"
          end
          arg_node = node.children[3]
          parse_data_value(label, arg_node)
        else
          raise "Unsupported DAta method #{method_name}"
        end
        return
      end

      # Type cast directives
      # this must be processed at compile time
      # Example
      # (recv).to_ixx(true|fasle) where xx is 64 or 32
      # -----
      # s(:begin,
      #    s(expression),
      #    :to_i64, [true|false])
      # the signed argument true|false is optional and 
      # it defaults to false
      if method_name == :to_i64 || method_name == :to_i32
        tgt_type = (method_name == :to_i64) ? Type::I64 : Type::I32
        if (cnt = node.children.count) == 3
          signed = true if node.children.last.type == :true
        elsif cnt == 2
          signed = false
        else
          raise "cast directive should have 0 or 1 argument (got #{cnt - 2})"
        end
        logger.debug "in cast section: child count #{cnt}, tgt_type #{tgt_type}, signed: #{signed}"

        # Parse the expression and cast it
        wn_to_cast = parse_node(recv_node, wnode)
        logger.debug("wn_to_cast: #{wn_to_cast}")
        wn_cast = @wgenerator.cast(wn_to_cast, tgt_type, signed)
        logger.debug("wn_cast: #{wn_cast}")
        # Drop last evaluated result if asked to
        @wgenerator.drop(wnode) unless keep_eval
        return wn_cast
      end

      # Regular Method call to self class
      # or another class
      # Example
      # self.m_one_arg(arg1, 200)
      # ---------
      # (send
      #   (self) :m_one_arg
      #   (lvar :arg1)
      #   (int 200)
      # )
      # OR
      # Test.m_one_arg(arg1, 200)
      # (send
      #   (const nil :Test) :m_one_arg
      #   (lvar :arg1)
      #   (int 200)
      # )
      if recv_node.type == :self  || recv_node.type == :const
        wn_call = @wgenerator.call(wnode, recv_node, method_name)
        arg_nodes = node.children[2..-1]
        arg_nodes.each { |node| parse_node(node, wn_call) }
        # Drop last evaluated result if asked to
        @wgenerator.drop(wnode) unless keep_eval
        return wn_call
      end

      # If receiver not self or const then it could
      # be an arithmetic or relational expression
      # Example 
      # 1 + 2
      # ----------
      # (send
      #   (int 1) :+
      #   (int 2)
      # )
      #
      # Example unary op
      # !(n==1)
      # (send
      #   (begin
      #     (send (lvar :n) :== (int 1))
      #  ) :!)


      # TODO must guess type arg from operator type
      logger.debug ">>> in expression section"
      logger.debug "  recv_node: #{recv_node} type: #{recv_node.type}"

      if ARITHMETIC_OPS.include?(method_name) ||
         RELATIONAL_OPS.include?(method_name) ||
         UNARY_OPS.include?(method_name)
        wn_op = @wgenerator.operator(wnode, method_name)
        wn_recv = parse_node(recv_node, wn_op)
    
        # now process the 2nd op arguments (there should
        # be only one but do as if we had several
        arg_nodes = node.children[2..-1]
        raise "method #{method_name} got #{arg_nodes.count} arguments (expected 1)" if arg_nodes.count > 1
        wn_args = arg_nodes.collect {|n| parse_node(n, wn_op)}

        @wgenerator.operands(wn_op, wn_recv, wn_args)
        logger.debug "  After type cast:  #{wn_op} wtype: #{wn_op.wtype}, op children types: #{wn_op.children.map(&:wtype)}"
        # Drop last evaluated result if asked to
        @wgenerator.drop(wnode) unless keep_eval
        return wn_op
      else
        raise "method #{method_name} not supported"
      end
    end

    # Data value node can be either of type
    # int, str, send, array
    def parse_data_value(label, node)
      case node.type
      when :int, :str
        logger.debug "in :int/:str label #{label}, value #{node.children.last}"
        DAta.append(label, node.children.last)
      when :array
        node.children.each {|n| parse_data_value(label,n)}
      when :send
        recv_node,method_name,arg_node = *node.children
        logger.debug "in send: recv_node #{recv_node}, method_name #{method_name}"
        case method_name
        when :to_i64
          raise "Data type casting can only apply to int (got #{recv_node}" \
            unless recv_node.type == :int
          value = recv_node.children.last
          DAta.append(label, value, Type::I64)
        when :[]
          raise "Initializer can only be a Data address (got #{node})" \
            unless recv_node.children.last == :DAta
          raise "Initializer expects a symbol (got #{arg_node})" \
            unless arg_node.type == :sym
          DAta.append(label, DAta[arg_node.children.last])
        else
          raise "Unknow data initializer #{node}"
        end
      else
        raise "Unknow data initializer #{node}"
      end
    end

    def parse_return(node, wnode, keep_eval)
      ret_count = node.children.count
      raise "only one or no value can be returned (got #{ret_count})" if ret_count > 1
      exp_node = node.children.first
      wn_ret = @wgenerator.return(wnode)
      if exp_node
        wn_exp = parse_node(exp_node, wn_ret)
        wn_ret.wtype = wn_exp.wtype
      else
        wn_ret.wtype = :none
      end
      wn_ret
    end

    # Process the if then else conditional statement
    # (the else clause can be absent) with a result
    # type
    # Example
    # if|unless (result type) expression
    #   ...
    # else
    #   ...
    # end
    # ----------
    # (if 
    #   (sexp)
    # (then
    #   ...
    # )
    # (else
    #   ...
    # )
    def parse_if_without_result_type(node, wnode, keep_eval)
      cond_node, then_node, else_node = *node.children
      # process the if clause
      # always keep eval on stack for the if statement
      wn_if = @wgenerator.if(wnode)
      parse_node(cond_node, wn_if, true)

      # process the then clause
      # DO NOT keep the last evaluated value
      # if then clause is nil it's probably
      # because it's actually an unless statement
      wn_then = @wgenerator.then(wn_if)
      if then_node
        parse_node(then_node, wn_then, false)
      else
        @wgenerator.nop(wn_then)
      end

      # The result type is always nil in this variant
      # of the parse_if_... method
      wn_if.wtype = nil; wn_then.wtype = nil

      # process the else clause if it exists
      # DO NOT keep the last evaluated value
      if else_node
        wn_else = @wgenerator.else(wn_if)
        parse_node(else_node, wn_else, false)
        wn_else.wtype = nil
      end
  
      # Drop last evaluated result if asked to
      # No need to drop the last evaluated value
      # here as the then and else branches do not
      # return any
      # @wgenerator.drop(wnode) unless keep_eval
      return wn_if
    end

    # Process the if then else conditional statement
    # (the Ruby else clause is optional) with a result
    # type
    # Example
    # if (result type) expression
    #   ...
    # else
    #   ...
    # end
    # ----------
    # (if 
    #   (sexp)
    # (then
    #   ...
    # )
    # (else
    #   ...
    # )
    def parse_if_with_result_type(node, wnode, keep_eval)
      cond_node, then_node, else_node = *node.children
      # process the if clause
      wn_if = @wgenerator.if(wnode)
      parse_node(cond_node, wn_if, true) # always keep eval on stack
      # process the then clause
      wn_then = @wgenerator.then(wn_if)
      parse_node(then_node, wn_then, keep_eval)

      # infer the result type of the if from the
      # the type of the then clause
      wn_then.wtype = wn_then.children.last.wtype
      wn_if.wtype = wn_then.wtype
      # Now that we know the result type 
      # prepend it to the if children
      logger.debug("prepending result to wnode #{wn_if}")
      @wgenerator.result(wn_if) unless wn_if.wtype.nil?

      # process the else clause if it exists
      wn_else = @wgenerator.else(wn_if)
      if else_node
        parse_node(else_node, wn_else, keep_eval)
        wn_else.wtype = wn_else.children.last.wtype
        if wn_then.wtype != wn_else.wtype
          raise "then and else clauses must return same wtype (got #{wn_then.wtype} and #{wn_else.wtype}"
        end
      else
        # if the else clause doesn't exist in Ruby we still
        # have to generate it in WAT because the else branch
        # **MUST** be there and return the same result type
        # as the then branch
        # In this case in Ruby the missing else clause would
        # cause the if statement to evaluate to nil if the
        # condition is false. Problem is "nil" doesn't exist in
        # Webassembly. For now let's return a "remarkable" value
        # (see NIL constant)
        # WARNING!! This is not satisfactory of course because
        # the then branch could one day return this exact same
        # value too
        #
        # A safer alternative (but not compliant with plain Ruby)
        # would be to assume that if-then-else in Rlang never
        # evaluates to a value (see method parse_if_without_result_type)
        @wgenerator.int(wn_else, wn_then.wtype, NIL)
        wn_else.wtype = wn_then.wtype
      end
  
      # Drop last evaluated result if asked to
      @wgenerator.drop(wnode) unless keep_eval
      return wn_if
    end

    # Example
    # (while (cond)
    #   (body)
    # end
    # -----------
    # (block $lbl_xx
    #  (loop $lbl_yy
    #    (br_if $lbl_xx (ixx.eqz (cond)))
    #    (body)
    #    (br $lbl_yy)
    #  )
    # )
    def parse_while_without_result_type(node, wnode, keep_eval)
      cond_node, body_node = *node.children
      wn_while,wn_while_cond,wn_body = @wgenerator.while(wnode)

      # Parse the while condition... 
      # Plus negate the condition if it's a while statement
      # Keep it as is for a until statement
      wn_cond_exp = parse_node(cond_node, wn_while_cond)
      if node.type == :while
        @wgenerator.while_cond(wn_while_cond, wn_cond_exp)
      end

      # Parse the body of the while block and 
      # do not keep the last evaluated expression
      parse_node(body_node, wn_body, false )
      @wgenerator.while_end(wn_body)
      return wn_while
    end

    def parse_break(node, wnode, keep_eval)
      @wgenerator.break(wnode)
    end

    def parse_next(node, wnode, keep_eval)
      @wgenerator.next(wnode)
    end

    # Ruby || operator
    # Example
    # n==1 || n==2
    # ------
    # (or
    #   (send (lvar :n) :== (int 1))
    #   (send (lvar :n) :== (int 2))
    # )
    # Ruby && operator
    # Example
    # n==1 && m==3
    # ------
    # (and
    #   (send (lvar :n) :== (int 1))
    #   (send (lvar :m) :== (int 3))
    # )
    def parse_logical_op(node, wnode, keep_eval)
      logger.debug "logical operator section : #{node.type}"
      cond1_node, cond2_node = *node.children
      # Prepare the operator wnode
      wn_op = @wgenerator.operator(wnode, node.type)
      # Parse operand nodes and attach them to the
      # operator wnode
      wn_cond1 = parse_node(cond1_node, wn_op)
      wn_cond2 = parse_node(cond2_node, wn_op)
      wn_op = @wgenerator.operands(wn_op, wn_cond1, [wn_cond2])
      # Drop last evaluated result if asked to
      @wgenerator.drop(wnode) unless keep_eval
      return wn_op
    end

    def dump
      @ast
    end
  end

end
