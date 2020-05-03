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
require_relative './parser/wtype'
require_relative './parser/wtree'
require_relative './parser/wnode'
require_relative './parser/ivar'
require_relative './parser/cvar'
require_relative './parser/lvar'
require_relative './parser/marg'
require_relative './parser/global'
require_relative './parser/data'
require_relative './parser/wgenerator'

module Rlang::Parser
  class Parser

    include Log

    # WARNING!! THIS IS A **VERY** NASTY HACK PRETENDING
    # THAT THIS int VALUE means NIL. It's totally unsafe 
    # of course as an expression could end up evaluating
    # to this value and not be nil at all. But I'm using
    # it for now in the xxxx_with_result_type variants of
    # some parsing methods (if, while,...)
    # NOTE: those variants with result type are **NOT** the
    # ones used by Rlang right now
    NIL = 999999999

    # export and import toggle for method declaration
    @@export, @@export_name = false, nil
    @@import, @@import_module_name, @@import_function_name = false, nil, nil


    attr_accessor :wgenerator, :source, :config

    def initialize(wgenerator, options={})
      @wgenerator = wgenerator
      # LIFO of parsed files (stacked by require)
      @requires = []
      config_init(options)
      logger.level = Kernel.const_get("Logger::#{@config[:log_level].upcase}")
      logger.formatter = proc do |severity, datetime, progname, msg|
        loc = caller_locations[3] # skip over the logger call itself
        "#{severity[0]}: #{File.basename(loc.path)}:#{loc.lineno}##{loc.label} > #{msg}\n"
      end
      # reset all persistent objects
      # TODO: change the design so those objects are 
      # stored with the parser instance and not in a
      # class variable
      Global.reset!
      Export.reset!
      DAta.reset!
    end

    def config_init(options)
      @config = {}
      @config[:LOADED_FEATURES] = []
      @config[:LOAD_PATH] = []
      @config[:__FILE__] = ''
      @config[:log_level] = 'FATAL'
      @config.merge!(options)
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
      if file
        @requires.pop
        @config[:__FILE__] = @requires.last
      end
    end

    def parse(source, wnode=nil)
      ast = ::Parser::CurrentRuby.parse(source)
      parse_node(ast, wnode || @wgenerator.root) if ast
    end

    # Parse Ruby AST node and generate WAT
    # code as a child of wnode
    # - node: the Ruby AST node to parse
    # - wnode: the parent wnode for the generated WAT code
    # - keep_eval: whether to keep the value of the evaluated
    #   WAT expression on stock or not
    def parse_node(node, wnode, keep_eval=true)
      raise "wnode type is incorrect (got #{wnode})" unless wnode.is_a?(WNode) || wnode.nil?
      logger.debug "\n---------------------->>\n" + 
        "Parsing node: #{node}, wnode: #{wnode.head}, keep_eval: #{keep_eval}"
      # Nothing to parse
      return if node.nil?  

      case node.type
      when :self
        wn = parse_self(node, wnode)

      when :class
        wn = parse_class(node, wnode)

      when :module
        wn = parse_module(node, wnode)

      when :defs
        wn = parse_defs(node, wnode, keep_eval)

      when :def
        wn = parse_def(node, wnode, keep_eval)

      when :begin
        wn = parse_begin(node, wnode, keep_eval)

      when :casgn
        wn = parse_casgn(node, wnode, keep_eval)

      when :ivasgn
        wn = parse_ivasgn(node, wnode, keep_eval)

      when :cvasgn
        wn = parse_cvasgn(node, wnode, keep_eval)

      when :gvasgn
        wn = parse_gvasgn(node, wnode, keep_eval)

      when :lvasgn
        wn = parse_lvasgn(node, wnode, keep_eval)

      when :op_asgn
        wn = parse_op_asgn(node, wnode, keep_eval)

      when :lvar
        wn = parse_lvar(node, wnode, keep_eval)

      when :ivar
        wn = parse_ivar(node, wnode, keep_eval)

      when :cvar
        wn = parse_cvar(node, wnode, keep_eval)

      when :gvar
        wn = parse_gvar(node, wnode, keep_eval)

      when :int
        wn = parse_int(node, wnode, keep_eval)
      
      when :float
        raise "float instructions not supported"
        #parse_float(node, wnode, keep_eval)

      when :nil
        raise "nil not supported"

      when :const
        wn = parse_const(node, wnode, keep_eval)

      when :send
        wn = parse_send(node, wnode, keep_eval)

      when :return
        wn = parse_return(node, wnode, keep_eval)
      
      when :if
        #parse_if_with_result_type(node, wnode, keep_eval)
        wn = parse_if_without_result_type(node, wnode, keep_eval)
      
      when :while
        #parse_while_with_result_type(node, wnode, keep_eval)
        wn = parse_while_without_result_type(node, wnode, keep_eval)
      
      when :until
        #parse_while_with_result_type(node, wnode, keep_eval)
        wn = parse_while_without_result_type(node, wnode, keep_eval)
      
      when :break
        wn = parse_break(node, wnode, keep_eval)

      when :next
        wn = parse_next(node, wnode, keep_eval)

      when :or, :and
        wn = parse_logical_op(node, wnode, keep_eval)

      when :true
        wn = parse_true(node, wnode, keep_eval)

      when :false
        wn = parse_false(node, wnode, keep_eval)

      when :str
        wn = parse_string(node, wnode, keep_eval)

      else
        raise "Unknown node type: #{node.type} => #{node}"
      end
      raise "wnode type is incorrect (got #{wn}) at node #{node}" unless wn.is_a?(WNode) || wn.nil?
      logger.debug "\n----------------------<<\n" + 
        "End parsing node: #{node}, parent wnode: #{wnode&.head}, keep_eval: #{keep_eval}\n generated wnode #{wn&.head}" +
        "\n----------------------<<\n"
      wn
    end

    def parse_begin(node, wnode, keep_eval)
      child_count = node.children.count
      logger.debug "child count: #{child_count}"
      wn = nil
      node.children.each_with_index do |n, idx|
        logger.debug "processing begin node ##{idx}..."
        # A begin block always evaluates to the value of
        # its **last** child except
        if (idx == child_count-1)
          local_keep_eval = keep_eval
        else
          local_keep_eval = false
        end
        logger.debug "node idx: #{idx}/#{child_count-1}, wnode type: #{wnode.type}, keep_eval: #{keep_eval}, local_keep_eval: #{local_keep_eval}"
        wn = parse_node(n, wnode, local_keep_eval)
        logger.debug "in begin: parsing node #{n} gives wnode #{wn&.head}"
      end
      return wn # return last wnode
    end

    # Example:
    # class Stack
    #  ... body ...
    # end
    # -----
    # (class
    #   (const nil :Stack) nil (begin ....)))
    #
    # class Stack < Array
    #  ... body ...
    # end
    # -----
    # (class
    #   (const nil :Stack) (const nil :Array) (begin ....)))
    def parse_class(node, wnode)
      class_const_node, super_class_const_node, body_node = *node.children
      raise "expecting a constant for class name (got #{const_node})" \
        unless class_const_node.type == :const

      # create the class wnode
      class_path = _build_const_path(class_const_node)
      super_class_path = _build_const_path(super_class_const_node)
      wn_class = @wgenerator.klass(wnode, class_path, super_class_path)

      # Parse the body of the class
      parse_node(body_node, wn_class) if body_node

      # We finished parsing the class body so
      # 1) postprocess instance variables
      # 2) generate wnodes for the new/initialize function
      # 2) generate wnodes for attribute accessors
      @wgenerator.ivars_setup(wn_class)
      @wgenerator.def_initialize(wn_class) # generate **BEFORE** new
      @wgenerator.def_new(wn_class)
      @wgenerator.def_attr(wn_class)
      wn_class
    end

    # Example:
    # module Kernel
    #  ... body ...
    # end
    # -----
    # (module
    #   (const nil :Kernel) nil (begin ....)))
    #
    def parse_module(node, wnode)
      const_node = node.children.first
      body_node = node.children.last
      raise "expecting a constant for module name (got #{const_node})" \
        unless const_node.type == :const
      
      module_path = _build_const_path(const_node)

      # create the module wnode
      wn_module = @wgenerator.module(wnode, module_path)
      # Parse the body of the module
      parse_node(body_node, wn_module) if body_node
      wn_module
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
    # Example (instance var)
    # @stack_ptr -= nbytes
    # ---
    # s(:op_asgn,
    #    s(:ivasgn, :@stack_ptr), :-, s(:lvar, :nbytes))
    #
    # Example (setter/getter)
    # p.size -= nunits
    # ---
    # (op-asgn
    #   (send
    #     (lvar :p) :size) :-
    #   (lvar :nunits))
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
      op_asgn_type = node.children.first.type
      logger.debug "op_asgn on #{op_asgn_type} / wnode: #{wnode.head}, keep_eval: #{keep_eval}"

      case op_asgn_type
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
        wn_op = @wgenerator.send_method(wn_var_set, gvar.wtype.class_path, op, :instance)
        # Create the var getter node as a child of operator node
        wn_var_get = @wgenerator.gvar(wn_op, gvar)

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
        wn_op = @wgenerator.send_method(wn_var_set, cvar.wtype.class_path, op, :instance)
        # Create the var getter node as a child of operator node
        wn_var_get = @wgenerator.cvar(wn_op, cvar)
      
      # Local variable case
      when :lvasgn
        var_asgn_node, op, exp_node = *node.children
        var_name = var_asgn_node.children.last

        # parse the variable setter node
        # Note: this will also create the variable setting
        # wnode as a child of wnode
        wn_var_set = parse_node(var_asgn_node, wnode, keep_eval)
        lvar = wnode.find_lvar(var_name) || wnode.find_marg(var_name)
        raise "Unknown local variable #{var_name}" unless lvar

        # Create the operator node (infer operator type from variable)
        wn_op = @wgenerator.send_method(wn_var_set, lvar.wtype.class_path, op, :instance)
        # Create the var getter node as a child of operator node
        wn_var_get = @wgenerator.lvar(wn_op, lvar)

      # Instance variable case
      # Example (instance var)
      # @stack_ptr -= nbytes
      # ---
      # s(:op_asgn,
      #    s(:ivasgn, :@stack_ptr), :-, s(:lvar, :nbytes))
      when :ivasgn
        raise "Instance variable can only be accessed in instance method scope" \
          unless wnode.in_instance_method_scope?
        var_asgn_node, operator, exp_node = *node.children
        var_name = var_asgn_node.children.last

        # To op_asgn to work, ivar must already be declared
        ivar = wnode.find_ivar(var_name)
        raise "Unknown instance variable #{var_name}" unless ivar

        # Create the top level variable setter node
        wn_var_set = @wgenerator.ivasgn(wnode, ivar)

        # Second argument of the setter is the operator wnode
        # Create it with wtype of receiver by default. We may
        # change that wtype with the operands call later on
        wn_op = @wgenerator.send_method(wn_var_set, ivar.wtype.class_path, operator, :instance)

        # now create the getter node as a child of the
        # operator
        wn_var_get = @wgenerator.ivar(wn_op, ivar)

        # The wasm code for the ivar setter wnode doesn't leave
        # any value on stack (store instruction). So if the last
        # evaluated value must be kept then load the ivar again
        @wgenerator.ivar(wnode, ivar) if keep_eval

      # setter/getter case
      # Example (setter/getter)
      # p.size -= nunits
      # ---
      # (op-asgn
      #   (send
      #     (lvar :p) :size) :-
      #   (lvar :nunits))
      when :send
        send_node, op, exp_node = *node.children
        recv_node, method_name = *send_node.children

        # Parse the receiver node ((lvar :p) in the example)
        # above to get its wtype
        # Force keep_eval to true whatever upper level 
        # keep_eval says
        wn_recv = parse_node(recv_node, wnode, true)

        # Create the top level setter call
        wn_var_set = @wgenerator.send_method(wnode, wn_recv.wtype.class_path, :"#{method_name}=", :instance)

        # First argument of the setter must be the recv_node
        wn_recv.reparent_to(wn_var_set)

        # Second argument of the setter is the operator wnode
        # Create it with wtype of receiver by default. We may
        # change that wtype with the operands call later on
        wn_op = @wgenerator.send_method(wn_var_set, wn_recv.wtype.class_path, op, :instance)

        # Parsing the send node will create the getter wnode
        # this is the first argument of the operator wnode,
        # the second is wn_exp below
        # Force keep_eval to true whatever upper level 
        # keep_eval says
        wn_var_get = parse_node(send_node, wn_op, true)

        # If the setter returns something and last evaluated value
        # must be ignored then drop it
        unless (keep_eval || wn_var_set.wtype.blank?)
          @wgenerator.drop(wnode)
          #@wgenerator.send_method(wnode, wn_recv.wtype.class_path, "#{method_name}", :instance)
        end
      else
        raise "op_asgn not supported for #{node.children.first}"
      end

      # Finally, parse the expression node and make it
      # the second child of the operator node
      # Last evaluated value must be kept of course
      wn_exp = parse_node(exp_node, wn_op, true)
      
      # And process operands (cast and such...)
      @wgenerator.operands(wn_op, wn_var_get, [wn_exp])

      return wn_var_set
    end

    # Example
    #   MYCONST = 2000
    # ---
    # (casgn nil :MYCONST
    #   (int 2000))
    def parse_casgn(node, wnode, keep_eval)
      class_path_node, constant_name, exp_node = *node.children
      const_path = _build_const_path(class_path_node) << constant_name

      # raise "dynamic constant assignment" unless wnode.in_class_scope?
      # unless class_path_node.nil?
      #  raise "constant assignment with class path not supported (got #{class_name_node})"
      # end
      
      # find the scope class
      k = wnode.find_current_class_or_module()

      if wnode.in_method_scope?
        # if exp_node is nil then this is the form of 
        # :casgn that comes from op_asgn
        const = wnode.find_const(const_path)
        if exp_node        
          if const.nil?
            # first constant occurence
            # type cast the constant to the wtype of the expression
            const = wnode.create_const(const_path, nil, 0, WType::DEFAULT)
            k.consts << const
            wn_casgn = @wgenerator.casgn(wnode, const)
            wn_exp = parse_node(exp_node, wn_casgn)
            const.wtype = wn_exp.wtype
          else
            # if const already exists then type cast the 
            # expression to the wtype of the existing const
            wn_casgn = @wgenerator.casgn(wnode, const)
            wn_exp = parse_node(exp_node, wn_casgn)
            @wgenerator.cast(wn_exp, const.wtype, false)
            logger.warning "Already initialized constant #{const.name}"
          end
        else
          raise "Constant #{const_path} not declared before" unless const
          wn_casgn = @wgenerator.casgn(wnode, const)
        end
        # to mimic Ruby push the constant value on stack if needed
        @wgenerator.const(wnode, const) if keep_eval
        return wn_casgn

      elsif wnode.in_class_scope? || wnode.in_root_scope?
        # If we are in class scope
        # then it is a class variable initialization
        # Parse the expression node to see if it's a ixx.const
        # in the end but get rid of it then because we are not
        # executing this code. Just statically initiliazing the 
        # const with the value
        wn_exp = parse_node(exp_node, wnode)
        raise "Constant initializer can only be an int or a constant/class (got #{wn_exp}" \
          unless wn_exp.const?
        if (const = wnode.find_const(const_path))
          logger.warn "already initialized constant #{const.path}"
          const.value = wn_exp.wargs[:value]
        else
          const = wnode.create_const(const_path, wn_exp.wargs[:value], wn_exp.wtype)
          k.consts << const
        end
        wnode.remove_child(wn_exp)
        logger.debug "Constant #{const_path} initialized with value #{const.value} and wtype #{const.wtype}"
        return nil
      else
        raise "Constant can only be defined in method or class scope"
      end
    end

    # Example
    #   $MYGLOBAL = 2000
    # ---
    # (gvasgn :MYGLOBAL
    #   (int 2000))
    #
    # Example with type cast
    # $MYGLOBAL = 2000.to_I64
    # ---
    # (gvasgn :MYGLOBAL
    #   (send (int 2000) :to_I64))
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
            # Do not export global for now
            #gvar.export! if self.config[:export_all]
            wn_gvasgn = @wgenerator.gvasgn(wnode, gvar)
            wn_exp = parse_node(exp_node, wn_gvasgn)
            gvar.wtype = wn_exp.wtype
          else
            # if gvar already exists then type cast the 
            # expression to the wtype of the existing gvar
            wn_gvasgn = @wgenerator.gvasgn(wnode, gvar)
            wn_exp = parse_node(exp_node, wn_gvasgn)
            @wgenerator.cast(wn_exp, gvar.wtype, false)
          end
        else
          raise "Global variable #{cv_name} not declared before" unless gvar
          wn_gvasgn = @wgenerator.gvasgn(wnode, gvar)
        end
        # to mimic Ruby push the variable value on stack if needed
        @wgenerator.gvar(wnode, gvar) if keep_eval
        return wn_gvasgn
      elsif true #wnode.in_class_scope?
        # If we are at root or in class scope
        # then it is a global variable initialization
        raise "Global op_asgn can only happen in method scope" unless exp_node
        # In the class or root scope 
        # it can only be a Global var **declaration**
        # In this case the expression has to reduce
        # to a const wnode that can be used as value
        # in the declaration (so it could for instance
        # Global[:label] = 10 or Global[:label] = 10.to_I64)
        # Then remove the generated wnode because it is not for
        # execution. It is just to get the init value
        wn_exp = parse_node(exp_node, wnode)
        raise "Global initializer can only be a int or a constant/class (got #{wn_exp})" \
          unless wn_exp.const?
        wnode.remove_child(wn_exp)
        if gvar
          gvar.value = wn_exp.wargs[:value]
        else
          gvar = Global.new(gv_name, wn_exp.wtype, wn_exp.wargs[:value])
        end
        # Do not export global for now
        #gvar.export! if self.config[:export_all]
        return nil
      else
        raise "Global can only be defined in method or class scope"
      end
    end


    # Example
    # @stack_ptr = 10 + nbytes
    # ---
    # s(:ivasgn, :@stack_ptr, s(:send, s(:int, 10), :+, s(:lvar, :nbytes)))
    def parse_ivasgn(node, wnode, keep_eval)
      iv_name, exp_node = *node.children

      raise "Instance variable #{iv_name} can only used in instance method scope" \
        unless wnode.in_instance_method_scope? 

      if (ivar = wnode.find_ivar(iv_name))
        # if ivar already exists then type cast the 
        # expression to the wtype of the existing ivar
        wn_ivasgn = @wgenerator.ivasgn(wnode, ivar)
        wn_exp = parse_node(exp_node, wn_ivasgn)
        logger.debug "Casting exp. wtype #{wn_exp.wtype} to existing ivar #{ivar.name} wtype #{ivar.wtype}"
        @wgenerator.cast(wn_exp, ivar.wtype, false)
      else
        # first ivar occurence, create it 
        ivar = wnode.create_ivar(iv_name)
        # parse the expression to determine its wtype
        wn_phony = @wgenerator.phony(wnode)
        wn_exp = parse_node(exp_node, wn_phony)
        # the ivar wtype is defined by the
        # wtype of the expression
        ivar.wtype = wn_exp.wtype
        wn_ivasgn = @wgenerator.ivasgn(wnode, ivar)
        wn_phony.reparent_children_to(wn_ivasgn)
        logger.debug "Setting new ivar #{ivar.name} wtype to #{wn_exp.wtype.name}"      
      end

      # The wasm code for the ivar setter wnode doesn't leave
      # any value on stack (store instruction). So if the last
      # evaluated value must be kept then load the ivar again
      @wgenerator.ivar(wnode, ivar) if keep_eval
      wn_ivasgn
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
            wn_exp = parse_node(exp_node, wn_cvasgn)
            cvar.wtype = wn_exp.wtype
          else
            # if cvar already exists then type cast the 
            # expression to the wtype of the existing cvar
            wn_cvasgn = @wgenerator.cvasgn(wnode, cvar)
            wn_exp = parse_node(exp_node, wn_cvasgn)
            @wgenerator.cast(wn_exp, cvar.wtype, false)
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
        # Parse the expression node to see if it's a ixx.const
        # in the end but get rid of it then because we are not
        # executing this code. Just statically initiliazing the 
        # cvar with the value
        wn_exp = parse_node(exp_node, wnode)
        raise "Class variable initializer can only be an int or a constant/class (got #{wn_exp}" \
          unless wn_exp.const?
        cvar = wnode.create_cvar(cv_name, wn_exp.wargs[:value], wn_exp.wtype)
        wnode.remove_child(wn_exp)
        logger.debug "Class variable #{cv_name} initialized with value #{cvar.value} and wtype #{cvar.wtype}"
        return
        
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
          wn_exp = parse_node(exp_node, wn_lvasgn)
          lvar.wtype = wn_exp.wtype
        else
          # if cvar already exists then type cast the 
          # expression to the wtype of the existing cvar
          wn_lvasgn = @wgenerator.lvasgn(wnode, lvar)
          wn_exp = parse_node(exp_node, wn_lvasgn)
          @wgenerator.cast(wn_exp, lvar.wtype, false)
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
    # ... @stack_ptr
    # ---
    # ... s(:ivar, :@stack_ptr)
    def parse_ivar(node, wnode, keep_eval)
      raise "Instance variable can only be accessed in instance method scope" \
        unless wnode.in_instance_method_scope?
      iv_name, = *node.children
      if (ivar = wnode.find_ivar(iv_name))
        wn_ivar = @wgenerator.ivar(wnode, ivar)
      else
        raise "unknown instance variable #{ivar_name}"
      end
      # Drop last evaluated result if asked to
      @wgenerator.drop(wnode) unless keep_eval
      wn_ivar
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
      logger.debug("node: #{node}, wnode: #{wnode.head}, keep_eval: #{keep_eval}")

      lv_name, = *node.children
      if (lvar = wnode.find_lvar(lv_name) || wnode.find_marg(lv_name))
        wn_lvar = @wgenerator.lvar(wnode, lvar)
      else
        raise "unknown local variable #{lv_name}"
      end
      # Drop last evaluated result if asked to 
      @wgenerator.drop(wnode) unless keep_eval
      return wn_lvar
    end

    def parse_int(node, wnode, keep_eval)
      value, = *node.children
      logger.debug "int: #{value} for parent wnode #{wnode.head} keep_eval:#{keep_eval}"
      wn_int = @wgenerator.int(wnode, WType::DEFAULT, value)
      # Drop last evaluated result if asked to
      @wgenerator.drop(wnode) unless keep_eval

      logger.debug "wn_int:#{wn_int} wtype:#{wn_int.wtype} keep_eval:#{keep_eval}"
      return wn_int
    end

    def parse_true(node, wnode, keep_eval)
      wn_true = @wgenerator.int(wnode, WType::DEFAULT, 1)
      # Drop last evaluated result if asked to
      @wgenerator.drop(wnode) unless keep_eval

      logger.debug "wn_true:#{wn_true} wtype:#{wn_true.wtype} keep_eval:#{keep_eval}"
      return wn_true
    end

    def parse_false(node, wnode, keep_eval)
      wn_false = @wgenerator.int(wnode, WType::DEFAULT, 0)
      # Drop last evaluated result if asked to
      @wgenerator.drop(wnode) unless keep_eval

      logger.debug "wn_false:#{wn_false} wtype:#{wn_false.wtype} keep_eval:#{keep_eval}"
      return wn_false
    end

    # Whenever a string literal is used in Rlang
    # in whatever scope (root, class or method scope)
    # the string literal must be allocated
    # statically.
    # Then if the literal is used in a method scope
    # we must instantiate a dynamic string object
    # and copy the initial static value in it
    def parse_string(node, wnode, keep_eval)
      string = node.children.last
      if wnode.in_method_scope?
        # allocate string dynamically
        wn_string = @wgenerator.string_dynamic_new(wnode, string)
      else
        # allocate string statically
        wn_string = @wgenerator.string_static_new(wnode, string)
      end
      # Drop last evaluated result if asked to
      @wgenerator.drop(wnode) unless keep_eval

      logger.debug "wn_string:#{wn_string} wtype:#{wn_string.wtype} keep_eval:#{keep_eval}"
      return wn_string
    end

    # Example
    # TestA::C::MYCONST
    # -------
    # (const (const (const nil :TESTA) :C) :MYCONST))
    def parse_const(node, wnode, keep_eval)
      # Build constant path from embedded const sexp
      const_path = _build_const_path(node)
      full_const_name = const_path.join('::')

      # See if constant exists. It should at this point
      unless (const = wnode.find_const(const_path))
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

    # class method definition
    # Example
    # s(:defs,
    #    s(:self), :push,
    #    s(:args,
    #      s(:arg, :value)),... )
    #-----
    # def self.push(value)
    #   ...
    # end
    def parse_defs(node, wnode, keep_eval)
      logger.debug "node: #{node}\nwnode: #{wnode.head}"
      if node.type == :def
        # we are being called from parse_def to define
        # a class method in addition to an instance method
        method_name, arg_nodes, body_node = *node.children
        recv_node = nil
      else
        recv_node, method_name, arg_nodes, body_node = *node.children
        raise "only class method is supported. Wrong receiver at #{recv_node.loc.expression}" \
          if recv_node.type != :self
      end
      logger.debug "Defining class method: #{method_name}"
      logger.debug "recv_node: #{recv_node}\nmethod_name: #{method_name}"

      # create corresponding func node
      wn_method = @wgenerator.def_method(wnode, method_name, :class)
      if @@import
        wn_import = @wgenerator.import_method(wn_method, @@import_module_name, @@import_function_name)
      end

      # collect method arguments
      parse_args(arg_nodes, wn_method)
      # Look for any result directive and parse it so 
      # that we know what the return type is in advance
      # If :nil for instance then it may change the way
      # we generate code in the body of the method
      if body_node && (result_node = body_node.children.find {|n| n.respond_to?(:type) && n.type == :send && n.children[1] == :result})
        logger.debug "result directive found: #{result_node}"
        parse_node(result_node, wn_method, keep_eval)
      end

      # method body -- A method evaluates to its last 
      # computed value unless a result :nil directive
      # is specified
      logger.debug "method_name: #{method_name}, wtype: #{wn_method.wtype}"
      raise "Body for imported method #{method_name} should be empty (got #{body_node})" \
        if (@@import && body_node)
      parse_node(body_node, wn_method, !wn_method.wtype.blank?)

      # Now that we have parsed the whole method we can 
      # prepend locals, result and method args to the
      # method wnode (in that order)
      @wgenerator.locals(wn_method)
      @wgenerator.result(wn_method)
      @wgenerator.params(wn_method)
      @wgenerator.export_method(wn_method, @@export_name) if (@@export || self.config[:export_all])
      logger.debug "Full method wnode: #{wn_method}"

      # reset method toggles
      self.class._reset_toggles

      return wn_method
    end

    # Instance method definition
    # Example
    # (def :push,
    #    (args,
    #      s(:arg, :value)),... )
    #-----
    # def push(value)
    #   ...
    # end
    def parse_def(node, wnode, keep_eval)
      logger.debug "node: #{node}\nwnode: #{wnode.head}"
      method_name, arg_nodes, body_node = *node.children
      logger.debug "Defining instance method: #{method_name}"

      # create corresponding func node
      wn_method = @wgenerator.def_method(wnode, method_name, :instance)
      if @@import
        wn_import = @wgenerator.import_method(wn_method, @@import_module_name, @@import_function_name)
      end

      # collect method arguments
      wn_args = parse_args(arg_nodes, wn_method)

      # Look for any result directive and parse it so 
      # that we know what the return type is in advance
      # If :nil for instance then it may change the way
      # we generate code in the body of the method
      if body_node && (result_node = body_node.children.find {|n| n.respond_to?(:type) && n.type == :send && n.children[1] == :result})
        logger.debug "result directive found: #{result_node}"
        parse_node(result_node, wn_method, keep_eval)
      end

      # method body -- A method evaluates to its last 
      # computed value unless a result :nil directive
      # is specified
      logger.debug "method_name: #{method_name}, wtype: #{wn_method.wtype}"
      parse_node(body_node, wn_method, !wn_method.wtype.blank?)

      # Now that we have parsed the whole method we can 
      # prepend locals, result and method args to the
      # method wnode (in that order)
      @wgenerator.locals(wn_method)
      @wgenerator.result(wn_method)
      @wgenerator.params(wn_method)
      @wgenerator.export_method(wn_method, @@export_name) if (@@export || self.config[:export_all])
      logger.debug "Full method wnode: #{wn_method}"

      # reset method toggles
      self.class._reset_toggles

      # if we are in a module then also define
      # the class method because we don't know
      # whether the module will be included or extended
      if wnode.in_module_scope?
        self.parse_defs(node, wnode, keep_eval)
      end
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
          if File.file?(full_path_file)
            logger.debug "Found required file: #{full_path_file}"
            break
          end
        end
      else
        case file
        when /^\./
          # If file starts with . then look for file in pwd
          load_path = [Dir.pwd]
        when /^rlang/
          # If it starts with rlang then look for it in the 
          # installed rlang gem in addition to load path
          load_path = self.config[:LOAD_PATH] + $LOAD_PATH
        else
          load_path = self.config[:LOAD_PATH]
          load_path = [Dir.pwd] if self.config[:LOAD_PATH].empty?
        end
        logger.debug "load_path: #{load_path} for file #{file}"

        # Now try each possible extension foreach possible
        # directory in the load path
        load_path.each do |dir|
          logger.debug "Searching in dir: #{dir}"
          break unless extensions.each do |ext|
            fpf = File.expand_path(File.join(dir, file+ext))
            if File.file?(fpf)
              logger.debug "Found required file: #{fpf}"
              full_path_file = fpf; break
            end
          end
        end
      end
      raise LoadError, "no such file to load: #{full_path_file}" unless full_path_file

      # Now load the file 
      if File.extname(full_path_file) == '.wat'
        wat_code = File.read(full_path_file)
        @wgenerator.inline(wnode, wat_code)
      else
        parse_file(full_path_file)
      end
    end

    def parse_require_relative(wnode, file)
      logger.debug "Require file: #{file}...\n   ...relative to #{self.config[:__FILE__]}"
      full_path_file = File.expand_path(file, File.dirname(self.config[:__FILE__]))
      parse_require(wnode, full_path_file)
    end

    # Parse the many differents forms of send
    # (both compile time directives and application calls)
    def parse_send(node, wnode, keep_eval)
      recv_node = node.children[0]
      method_name = node.children[1]
      logger.debug "recv_node #{recv_node}, method_name : #{method_name}"
      logger.debug "scope: #{wnode.scope}"

      if recv_node.nil?
        return parse_send_nil_receiver(node, wnode, keep_eval)
      end
      
      # Special case : DAta initializers
      #
      # Example (setting DAta address)
      # DAta.address = 0
      # ---------
      # (send
      #   (const nil :DAta) :address=
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
      # DAta[:an_I64] = 3200.to_I64
      # ---------
      # (send
      #  (const nil :DAta) :[]=
      #  (sym :an_I64)
      #  (send
      #    (int 32000) :to_Ixx))
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
        when :address=
          value_node = node.children[2]
          raise "DAta address must be an integer" unless value_node.type == :int
          DAta.address = value_node.children.last
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

      # General type cast directive
      # this must be processed at compile time. It's not dynamic
      # An expression can be cast to any Rlang class including
      # native types like :I64,:I32,...
      #
      # Example
      # (expression).cast_to(class_name, argument)    
      # -----
      # s(:begin,
      #    s(expression),
      #    :cast_to, s(sym, :Class_name))
      # the signed argument true|false is optional and 
      # it defaults to false
      # Class_name is a symbol like :A or :"A:B" or :"A:B:C"
      if method_name == :cast_to
        class_name_node = node.children.last
        raise "cast_to expects a symbol argument (got #{class_name_node}" unless class_name_node.type == :sym
        tgt_wtype = WType.new(class_name_node.children.first)
        logger.debug "in cast_to: target type #{tgt_wtype}"

        # Parse the expression and cast it
        wn_to_cast = parse_node(recv_node, wnode)
        logger.debug("wn_to_cast: #{wn_to_cast}")
        wn_cast = @wgenerator.cast(wn_to_cast, tgt_wtype)
        logger.debug("wn_cast: #{wn_cast}")
        # Drop last evaluated result if asked to
        @wgenerator.drop(wnode) unless keep_eval
        return wn_cast
      end


      # Type cast directives specific for native types
      # can pass the signed argument wheres cast_to cannot
      # this must be processed at compile time. It's not dynamic
      # Example
      # (recv).to_Ixx(true|fasle) where xx is 64 or 32
      # -----
      # s(:begin,
      #    s(expression),
      #    :to_I64, [true|false])
      # the signed argument true|false is optional and 
      # it defaults to false
      if method_name == :to_I64 || method_name == :to_I32
        tgt_wtype = (method_name == :to_I64) ? WType.new(:I64) : WType.new(:I32)
        if (cnt = node.children.count) == 3
          signed = true if node.children.last.type == :true
        elsif cnt == 2
          signed = false
        else
          raise "cast directive should have 0 or 1 argument (got #{cnt - 2})"
        end
        logger.debug "in cast section: child count #{cnt}, tgt_wtype #{tgt_wtype}, signed: #{signed}"

        # Parse the expression and cast it
        wn_to_cast = parse_node(recv_node, wnode)
        logger.debug("wn_to_cast: #{wn_to_cast}")
        wn_cast = @wgenerator.cast(wn_to_cast, tgt_wtype, signed)
        logger.debug("wn_cast: #{wn_cast}")
        # Drop last evaluated result if asked to
        @wgenerator.drop(wnode) unless keep_eval
        return wn_cast
      end

      # addr method applied to statically allocated variables
      # only constant and class variables returns their address 
      # in memory
      #
      # Example
      # @@argv_bu_size.addr
      # ---
      # (send (cvar :@@argv_buf_size) :addr)
      #
      if method_name == :addr
        if recv_node.type == :const
          # Build constant path from embedded const sexp
          const_path = _build_const_path(recv_node)
          full_const_name = const_path.join('::')

          # See if constant exists. It should at this point
          unless (const = wnode.find_const(const_path))
            raise "unknown constant #{full_const_name}"
          end
          wn_const_addr = @wgenerator.const_addr(wnode, const)

          # Drop last evaluated result if asked to
          @wgenerator.drop(wnode) unless keep_eval
          return wn_const_addr

        elsif recv_node.type == :cvar
          raise "Class variable can only be accessed in method scope" \
            unless wnode.in_method_scope?
          cv_name = recv_node.children.first
          if (cvar = wnode.find_cvar(cv_name))
            wn_cvar_addr = @wgenerator.cvar_addr(wnode, cvar)
          else
            raise "unknown class variable #{cv_name}"
          end
          # Drop last evaluated result if asked to
          @wgenerator.drop(wnode) unless keep_eval
          return wn_cvar_addr

        else
          # Do nothing. This will be treated as a regular method call
        end
      end

      # A that stage it's a method call of some sort
      # (call on class or instance)
      return parse_send_method_lookup(node, wnode, keep_eval)

    end

    def parse_send_nil_receiver(node, wnode, keep_eval)
      recv_node = node.children[0]
      method_name = node.children[1]
      raise "receiver should be nil here (got #{recv_node})" \
        unless recv_node.nil?

      if recv_node.nil? && method_name == :require
        return parse_send_require(node, wnode, keep_eval)
      end

      if recv_node.nil? && method_name == :require_relative
        return parse_send_require_relative(node, wnode, keep_eval)
      end

      if recv_node.nil? && method_name == :include
        return parse_send_include(node, wnode, keep_eval)
      end

      if recv_node.nil? && method_name == :prepend
        return parse_send_prepend(node, wnode, keep_eval)
      end

      if recv_node.nil? && method_name == :extend
        return parse_send_extend(node, wnode, keep_eval)
      end

      if recv_node.nil? && method_name == :export
        return parse_send_export(node, wnode, keep_eval)
      end

      if recv_node.nil? && method_name == :import
        return parse_send_import(node, wnode, keep_eval)
      end

      if recv_node.nil? && method_name == :local
        return parse_send_local(node, wnode, keep_eval)
      end

      if  recv_node.nil? && method_name == :arg
        return parse_send_arg(node, wnode, keep_eval)
      end

      if recv_node.nil? && method_name == :result 
        return parse_send_result(node, wnode, keep_eval)
      end

      if recv_node.nil? && method_name.to_s =~ /^attr_(reader|writer|accessor)/
        return parse_send_attr(node, wnode, keep_eval)
      end

      if recv_node.nil? && method_name == :attr_type
        return parse_send_attr_type(node, wnode, keep_eval)
      end

      if recv_node.nil? &&  method_name == :inline
        return parse_send_inline(node, wnode, keep_eval)
      end

      # All other cases : it is a regular method call
      return parse_send_method_lookup(node, wnode, keep_eval)
    end

    # Directive to require a file
    # Example
    # (send nil :require
    #   (str "test5"))
    def parse_send_require(node, wnode, keep_eval)
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
    def parse_send_require_relative(node, wnode, keep_eval)
      raise "require_relative must be used at root level" \
        unless wnode.in_root_scope?
      file_node = node.children.last
      raise "require only accepts a string argument (got #{file_node})" \
        unless file_node.type == :str
      parse_require_relative(wnode, file_node.children.last)
      return
    end

    # Directive to include a module
    # current file
    # Example
    # include Kernel
    # ----
    # (send nil :include
    #   (const nil :Kernel))
    def parse_send_include(node, wnode, keep_eval)
      const_node = node.children.last
      module_path = _build_const_path(const_node)
      raise "expecting a constant for include (got #{const_node})" \
        unless const_node.type == :const
      raise "include must be used in class scope" \
        unless wnode.in_class_scope?
      @wgenerator.include(wnode, module_path)
    end

    # Directive to prepend a module
    # current file
    # Example
    # prepend MyModule
    # ----
    # (send nil :prepend
    #   (const nil :MyModule))
    def parse_send_prepend(node, wnode, keep_eval)
      const_node = node.children.last
      module_path = _build_const_path(const_node)
      raise "expecting a constant for prepend (got #{const_node})" \
        unless const_node.type == :const
      raise "prepend must be used in class scope" \
        unless wnode.in_class_scope?
      @wgenerator.prepend(wnode, module_path)
    end

    # Directive to extend a module
    # current file
    # Example
    # extend Kernel
    # ----
    # (send nil :extend
    #   (const nil :Kernel))
    def parse_send_extend(node, wnode, keep_eval)
      const_node = node.children.last
      module_path = _build_const_path(const_node)
      raise "expecting a constant for extend (got #{const_node})" \
        unless const_node.type == :const
      raise "extend must be used in class scope" \
        unless wnode.in_class_scope?
      @wgenerator.extend(wnode, module_path)
    end

    # Directive to declare the current method
    # in the WASM exports
    # Example
    #
    # export
    # ---
    # (send nil :export)
    # OR
    # export :function_name
    # ---
    # (send nil :export
    #   (sym :function_name))
    #
    # With out an explicit function name, the export name
    # will be automatically built from the class/method names
    def parse_send_export(node, wnode, keep_eval)
      logger.debug "Export directive found for..."
      raise "export must be used in class scope" unless wnode.in_class_or_module_scope?
      @@export = true
      if (function_node = node.children[2])
        raise "export function name must be a symbol (got #{function_node})" \
          unless function_node.type == :sym  
        @@export_name = function_node.children.last
      end
      logger.debug "... #{@@export_name}"
      return
    end

    # Directive to declare the current method
    # in the WASM imports
    # Example
    #
    # import :module_name, :function_name
    # ---
    # (send nil :import
    #   (sym :mod)
    #   (sym :func))
    #
    def parse_send_import(node, wnode, keep_eval)
      logger.debug "Import directive found for..."
      raise "export must be used in class scope" unless wnode.in_class_or_module_scope?
      raise "import expects 2 arguments (got #{node.children.count - 2})" \
        unless node.children.count == 4
      
      module_node, function_node = node.children[2..-1]
      raise "import module name must be a symbol (got #{module_node})" \
        unless module_node.type == :sym    
      raise "import function name must be a symbol (got #{function_node})" \
        unless function_node.type == :sym
      @@import = true
      @@import_module_name   = module_node.children.last
      @@import_function_name = function_node.children.last
      logger.debug "... #{@@import_module_name}, #{@@import_function_name}"
      return
    end

    # Directive to define local variable type
    # this must be processed at compile time
    # if method name is :local then it is
    # a type definition for a local variable
    # local :value, :I64
    # ---------
    # s(:send, nil, :local,
    #  (hash
    #     (pair
    #       s(:sym, :value)
    #       s(:sym, :I64))
    # ))
    def parse_send_local(node, wnode, keep_eval)
      raise "local declaration can only be used in methods" \
        unless wnode.in_method_scope?
      hash_node = node.children.last
      local_types = parse_type_args(hash_node, :local)
      local_types.each do |name, wtype|
        lvar = wnode.find_or_create_lvar(name)
        raise "couldn't find or create local variable #{name}" unless lvar
        lvar.wtype = WType.new(wtype)
      end
      return
    end

    # Directive to define method argument type
    # this must be processed at compile time
    # if method name is :arg then it is
    # a type definition for a method argument
    # arg value: :I64
    # ---------
    # s(:send, nil, :arg,
    #  (hash
    #     (pair
    #       s(:sym, :value)
    #       s(:sym, :I64))
    # ))
    def parse_send_arg(node, wnode, keep_eval)
      raise "arg declaration can only be used in methods" \
        unless wnode.in_method_scope?
      hash_node = node.children.last
      marg_types = parse_type_args(hash_node, :argument)
      marg_types.each do |name, wtype|
        marg = wnode.find_marg(name)
        raise "couldn't find method argument #{name}" unless marg
        marg.wtype = WType.new(wtype)
      end
      return
    end

    # result directive in method scope
    # ======
    # Directive to define method return type
    # in the method itself
    # this must be processed at compile time
    # Supported types : :I32, :I64, :none 
    # (:nil means no value is returned)
    # 
    # Example
    # result :I64
    # ---------
    # s(:send, nil, :result,
    #   s(:sym, :I64))
    #
    # result directive in class scope
    # ======
    # Directive to define method return type
    # at the class level. This allows to declare
    # a method type before the method is parsed
    # this must be processed at compile time
    # Supported types : :I32, :I64, :none 
    # (:none means no value is returned)
    #
    # Example
    # result :MyClass, :split, :I64
    # result :"ClassA::MyClass", :split, :Header
    # ---------
    # s(:send, nil, :result,
    #   s(:sym, :class_path),
    #   s(:sym, :method_name),
    #   s(:sym, :I64))
    #
    # if name starts with # it's a n instance method,
    # otherwise a class method
    # Note: class path can be either A or A::B
    def parse_send_result(node, wnode, keep_eval)
      if wnode.in_method_scope?
        result_type, = *node.children[2]
        raise "result directive expects a symbol argument (got #{result_type})" \
          unless result_type.is_a? Symbol
        wnode.method_wnode.wtype = WType.new(result_type)
        logger.debug "result_type #{result_type} updated for method #{wnode.method_wnode.method}"
      elsif wnode.in_class_scope?
        class_path_name,  = *node.children[2]
        method_name, = *node.children[3]
        result_type, = *node.children[4]
        raise "result directive expects a symbol argument (got #{result_type}) in node #{node}" \
          unless result_type.is_a? Symbol
        @wgenerator.declare_method(wnode, WType.new(class_path_name), method_name.to_sym, result_type)
      else
        raise "result declaration not supported #{wn.scope} scope"
      end
      return
    end

    # Directive to define class attributes. This defines
    # a list of getters and setters and access them in
    # memory with an offset from the base address given as
    # an argument.
    #
    # xxxxx below can be reader, writer, accessor
    #
    # Example
    # attr_xxxxx :ptr, :size
    # ---------
    # s(:send, nil, :attr,
    #   s(:sym, :ptr),
    #   s(:sym, :size))
    def parse_send_attr(node, wnode, keep_eval)
      raise "attr directives can only happen in class scope" \
        unless wnode.in_class_scope?
      
      # check accessor directive is valid
      attr_access = node.children[1].to_s
      raise "Unknown kind of attribute accessor: #{attr_access}" \
        unless ['attr_reader', 'attr_writer', 'attr_accessor'].include? attr_access
      # scan through all attributes
      attr_nodes = node.children[2..-1]
      attr_nodes.each do |an|
        logger.debug "processing attr node #{an}"
        raise "attribute name must be a symbol (got #{an})" unless an.type == :sym
        attr_name = an.children.last
        if (attr = wnode.find_attr(attr_name))
          raise "attribute #{attr_name} already declared" if attr
        else
          attr = wnode.create_attr(attr_name)
          attr.export!
        end
        attr.send(attr_access)
      end
      nil
    end

    # Directive to specify wasm type of class attributes
    # in case it's not the default type 
    #
    # Example
    # attr_type ptr: :Header, size: :I32
    # ---------
    # s(:send, nil, :attr_type,
    #   (hash
    #     (pair
    #       s(:sym, :ptr)
    #       s(:sym, :Header))
    #     (pair
    #       s(:sym, :size)
    #       s(:sym, :I32))   ))
    #
    def parse_send_attr_type(node, wnode, keep_eval)
      raise "attr directives can only happen in class scope" \
        unless wnode.in_class_scope?
      hash_node = node.children.last
      attr_types = parse_type_args(hash_node, :attribute)
      attr_types.each do |name, wtype|
        logger.debug "Setting attr #{name} type to #{wtype}"
        if (attr = wnode.find_attr(name))
          # TODO find a way to update both wtype at once
          attr.wtype = WType.new(wtype)
        else
          raise "Unknown class attribute #{name} in #{wnode.head}"
        end          
      end
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
    def parse_send_inline(node, wnode, keep_eval)
      raise "inline can only happen in a method body or at root" \
        unless wnode.in_method_scope? || wnode.in_root_scope?
      hash_node = node.children.last
      raise "inline expects a hash argument (got #{hash_node.type}" \
        unless hash_node.type == :hash

      # Find the :wat entry in hash
      logger.debug "Hash node: #{hash_node} "
      wat_node = hash_node.children.\
        find {|pair| sym_node, = *pair.children; sym_node.children.last == :wat}
      raise "inline has no wat: hash entry" unless wat_node
      logger.debug "inline wat entry: #{wat_node}"

      # Find the :wtype entry in hash if any
      wtype_node = hash_node.children.\
        find {|pair| sym_node, = *pair.children; sym_node.children.last == :wtype}
      if wtype_node
        wtype = WType.new(wtype_node.children.last.children.last)
        logger.debug "inline wtype entry: #{wtype_node}"
      else
        wtype = WType::DEFAULT
      end
      logger.debug "wtype: #{wtype} "

      # Now extract the WAT code itself
      raise "inline has no wat: hash entry" unless wat_node
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
      @wgenerator.drop(wnode) unless (keep_eval || wtype.blank?)
      return wn_inline
    end

    # Determine whether it's an instance or class method call
    # TODO : see how to remove identical code between class
    # and instance method calls below
    def parse_send_method_lookup(node, wnode, keep_eval)
      recv_node = node.children[0]
      #method_name = node.children[1]
      #if wnode.in_class_scope? || wnode.in_class_method_scope? || wnode.in_root_scope?
        if recv_node.nil? || recv_node.type == :self
          if wnode.in_instance_method_scope?
            return parse_send_instance_method_call(node, wnode, keep_eval)
          else
            return parse_send_class_method_call(node, wnode, keep_eval)
          end
        elsif recv_node.type == :const
          const_path = _build_const_path(recv_node)
          # if this is a Constant, not a class
          # then it's actually an instance method call
          raise "Unknown constant #{const_path}" unless (c = wnode.find_const(const_path))
          if (c.class? || c.module?)
            return parse_send_class_method_call(node, wnode, keep_eval)
          else
            return parse_send_instance_method_call(node, wnode, keep_eval)
          end            
        else
          return parse_send_instance_method_call(node, wnode, keep_eval)
        end
    end

    # Regular class Method call to self class
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
    #
    # OR New object instantiation
    # This is class object instantiation. Statically 
    # allocated though. So it can only happen in the
    # class scope for a class variable or a constant
    # Example
    # self.new
    # ---------
    # (send
    #   (self) :new) )
    # 
    # OR
    # Header.new
    # ---------
    # (send
    #   (const nil :Header) :new) )
    #
    def parse_send_class_method_call(node, wnode, keep_eval)
      logger.debug "Parsing class method call..."
      recv_node = node.children[0]
      method_name = node.children[1]
      if recv_node.nil? || recv_node.type == :self
        # differ class_name identification to
        class_path = []
      elsif recv_node.type == :const
        class_path = _build_const_path(recv_node)
      else
        raise "Can only call method class on self or class objects (got #{recv_node} in node #{node})"
      end
      logger.debug "...#{class_path}::#{method_name}"
      if method_name == :new && (wnode.in_class_scope? || wnode.in_root_scope?)
        # This is class object instantiation. Statically 
        # allocated though. So it can only happen in the
        # class scope for a class variable or a constant
        # Returns a wnode with a i32.const containing the address
        wn_addr = @wgenerator.static_new(wnode, class_path)
        return wn_addr
      else
        wn_call = @wgenerator.send_method(wnode, class_path, method_name, :class)
        arg_nodes = node.children[2..-1]
        arg_nodes.each { |node| parse_node(node, wn_call) }
        # Drop last evaluated result if asked to or if
        # the method called doesn't return any value
        @wgenerator.drop(wnode) unless (keep_eval || wn_call.wtype.blank?)
        return wn_call
      end
      raise "FATAL ERROR!! Unreachable point at end of parse_send_class_method_call (node: #{node})"
    end

    # Instance Method lookup and native operator
    #
    # In the example below mem_size would be
    # recognized as a local var because it was not 
    # assigned a value before. It's recognized as
    # a tentative method call
    # Example
    #  some_var = mem_size + 10
    # ------
    # (send
    #   (send nil :mem_size) :+
    #   (int 10))
    #
    # Example for method call on class instance
    # @@cvar.x = 100
    # ----------
    # (send
    #   (cvar :@@cvar) :x= (int 100)
    # )
    # 
    # If receiver not self or const then it could
    # be an arithmetic or relational operator or
    # an operato overloaded in the related class
    #
    # Example for binary op
    # 1 + 2
    # ----------
    # (send
    #   (int 1) :+
    #   (int 2)
    # )
    #
    # Example unary op
    # !(n==1)
    # ----------
    # (send
    #   (begin
    #     (send (lvar :n) :== (int 1))
    #  ) :!)
    #
    def parse_send_instance_method_call(node, wnode, keep_eval)
      logger.debug "Parsing instance method call..."
      recv_node = node.children[0]
      method_name = node.children[1]
      # Parse receiver node and temporarily attach it
      # to parent wnode. It will later become the first
      # argument of the method call by reparenting it
      logger.debug "Parsing instance method call #{method_name}, keep_eval: #{keep_eval}..."
      logger.debug "... on receiver #{recv_node}..."

      # parse the receiver node just to know its wtype
      # if nil it means self
      wn_phony = @wgenerator.phony(wnode)

      wn_recv = recv_node.nil? ? parse_self(recv_node, wn_phony) : parse_node(recv_node, wn_phony)
      logger.debug "Parsed receiver : #{wn_recv} / wtype: #{wn_recv.wtype}"

      # Invoke method call
      wn_op = @wgenerator.send_method(wnode, wn_recv.wtype.class_path, method_name, :instance)

      # reparent the receiver wnode(s) to operator wnode
      wn_phony.reparent_children_to(wn_op)
      wnode.remove_child(wn_phony)

      # Grab all arguments and add them as child of the call node
      arg_nodes = node.children[2..-1]
      wn_args = arg_nodes.collect do |n| 
        logger.debug "...with arg #{n}"
        parse_node(n, wn_op, true)
      end

      # now cast operands (will do nothing if it's a method call)
      @wgenerator.operands(wn_op, wn_recv, wn_args)
      logger.debug "After operands, call wnode: #{wn_op} wtype: #{wn_op.wtype}, wn_op children types: #{wn_op.children.map(&:wtype)}"

      # Drop last evaluated result if asked to or if
      # the method called doesn't return any value
      @wgenerator.drop(wnode) unless (keep_eval || wn_op.wtype.blank?)

      return wn_op
    end

    def parse_type_args(hash_node, entity)
      types = {}
      # Is this a hash Node ?
      unless hash_node.respond_to?(:type) && hash_node.type == :hash
        raise "#{entity} expects a hash argument (got #{hash_node}" \
      end
      logger.debug "#{entity} hash node: #{hash_node}"
      hash_node.children.each do |pair_node|
        name_node, type_node = pair_node.children
        raise "The name of an #{entity} must be a symbol (got #{name_node})" \
          unless name_node.type == :sym
        raise "The type of an #{entity} must be a symbol (got #{type_node})" \
          unless type_node.type == :sym
        name = name_node.children.last
        type = type_node.children.last
        types[name] = type
      end
      types
    end

    # Parse self. We should ge there only
    # when sis an object instance (not a class instance)
    def parse_self(node, wnode)
      if  wnode.in_instance_method_scope?
        wn = @wgenerator._self_(wnode)
        logger.debug "self in instance method scope"
      elsif wnode.in_class_method_scope?
        # Nothing to do just return nil
        # TODO: not sure this is the right thing to do. Double check
        logger.debug "self in class method scope. Nothing to do."
      elsif wnode.in_class_scope?
        # Nothing to do just return nil
        # TODO: not sure this is the right thing to do. Double check
        logger.debug "self in class definition scope. Nothing to do."
      else
        raise "Don't know what self means in this context: #{wnode.head}"
      end 
      wn
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
        when :to_I64
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
        wn_ret.wtype = WType.new(:none)
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
      wn_if.wtype = WType.new(:nil); wn_then.wtype = WType.new(:nil)

      # process the else clause if it exists
      # DO NOT keep the last evaluated value
      if else_node
        wn_else = @wgenerator.else(wn_if)
        parse_node(else_node, wn_else, false)
        wn_else.wtype = WType.new(:nil)
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
      @wgenerator.result(wn_if) unless wn_if.wtype.blank?

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
      parse_node(body_node, wn_body, false)
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
      wn_op = @wgenerator.native_operator(wnode, node.type)
      # Parse operand nodes and attach them to the
      # operator wnode
      wn_cond1 = parse_node(cond1_node, wn_op)
      wn_cond2 = parse_node(cond2_node, wn_op)
      @wgenerator.operands(wn_op, wn_cond1, [wn_cond2])
      # Drop last evaluated result if asked to
      @wgenerator.drop(wnode) unless keep_eval
      return wn_op
    end

    def _build_const_path(node)
      logger.debug "Building constant path..."
      const_path = []; n = node
      while n
        raise "expecting a const node (got #{n})" unless n.type == :const
        logger.debug "adding #{n.children.last} to constant path"
        const_path.unshift(n.children.last)
        n = n.children.first
      end
      logger.debug "... #{const_path}"
      const_path
    end

    def self._reset_toggles
      @@export, @@export_name = false, nil
      @@import, @@import_module_name, @@import_function_name = false, nil, nil
    end

    def dump
      @ast
    end
  end

end
