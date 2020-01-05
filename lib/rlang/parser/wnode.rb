# Rubinius WebAssembly VM
# Copyright (c) 2019, Laurent Julliard and contributors
# All rights reserved.
#
# Nodes used to generate WASM code 

require_relative  '../../utils/log'
require_relative './const'
require_relative './cvar'
require_relative './lvar'
require_relative './method'

module Rlang::Parser
  class WNode
    include Log

    # WASM code templates
    T = {
      func: 'func %{func_name}',
      param: 'param %{name} %{wasm_type}',
      result: 'result %{wasm_type}',
      return: 'return',
      local: 'local %{name} %{wasm_type}',
      call: 'call %{func_name}',
      store: '%{wasm_type}.store',
      load: '%{wasm_type}.load',
      local_get: 'local.get %{var_name}',
      local_set: 'local.set %{var_name}',
      global_get: 'global.get %{var_name}',
      global_set: 'global.set %{var_name}',
      addr: 'i32.const %{addr}',
      operator: '%{wasm_type}.%{operator}',
      const: '%{wasm_type}.const %{value}',
      drop: 'drop',
      nop: 'nop',
      extend_i32_u: '%{wasm_type}.extend_i32_u',
      extend_i32_s: '%{wasm_type}.extend_i32_s',
      wrap_i64: '%{wasm_type}.wrap_i64',
      eqz: '%{wasm_type}.eqz',
      if: 'if',
      then: 'then',
      else: 'else',
      block: 'block %{label}',
      loop: 'loop %{label}',
      br_if: 'br_if %{label}',
      br: 'br %{label}',
      inline: '%{code}',
    }

    attr_accessor :type, :wargs, :children, :parent, :comment, :lvars, :cvars, :margs,
                  :consts, :methods, :method, :template, :keep_on_stack,
                  :class_wnodes
    attr_reader   :wtype, :label, :klass_name

    @@label_index = 0

    def initialize(type, parent=nil, prepend=false)
      @type = type # :root, :method, :class, :insn, :none
      @parent = parent
      @comment = nil

      @wargs = {}
      @template = nil
      @children = []
      @@root = self if type == :root
      # make this wnode a child of its parent
      @parent.add_child(self, prepend) if @parent

      # WASM type of this node. If node is :method
      # then it's the type of the return value (nil
      # means no value returned)
      @wtype = Type::DEFAULT_TYPE

      # For root wnode
      @class_wnodes = [] # wnodes of classes

      # For class wnode only
      @klass_name = nil
      @cvars   = [] # class variables=
      @consts  = [] # class constants
      @methods = [] # methods

      # For method wnode only
      @method = nil
      @margs = []   # method args
      @lvars = []   # local variables
      
      # For insn wnode with 
      # label (.e.g block, loop)
      @label = nil
    end

    def self.root
      @@root
    end

    def root?
      self == @@root
    end

    # set instruction template and args
    def c(template, wargs = {})
      raise "Error: unknown WASM code template (#{template})" unless T.has_key? template
      raise "Error: this WNode is already populated with instruction #{@template}" if @template
      if [:loop, :block].include? template
        wargs[:label] = self.set_label
      end
      @template = template
      @wargs = wargs
      #self.wtype = wargs[:wtype] if wargs.has_key? :wtype
    end

    def wasm_code
      @wargs[:wasm_type] ||= self.wasm_type
      T[@template] ? T[@template] % @wargs : ''
    end

    def wasm_type
      @wtype ? @wtype.wasm_type : ''
    end
    
    def set_label
      @label = "$lbl_#{'%02d' % (@@label_index += 1)}"
    end

    # Specify the WASM type of this node
    def wtype=(wtype)
      if wtype.is_a? Symbol
        # wtype can be provided as a short symbol :I32, :I64,...
        if wtype == :none || wtype == nil
          @wtype = nil
        else
          @wtype = Type::ITYPE_MAP[wtype]
        end
      elsif wtype.nil? || wtype.ancestors.include?(Numeric)
        # or as a Type class or nil
        @wtype = wtype
      else
        raise "Error: unknown wtype #{wtype.inspect}"
      end
      @method.wtype = @wtype if self.method?
      # update wasm_type template arg accordingly
      logger.debug "type #{self.type} wargs #{self.wargs} wtype #{@wtype.inspect}"
      @wargs[:wasm_type] = @wtype.wasm_type if @wtype
      @wtype
    end

    # Add a new child to current node at the 
    # end or at the beginning of the child list
    def add_child(wnode, prepend=false)
      #logger.debug "Adding #{wnode.object_id} to #{self.object_id} (children: #{self.children.map(&:object_id)})"
      if prepend
        self.children.unshift(wnode)
      else
        self.children << wnode
      end
      wnode.parent = self
      #logger.debug "Added #{wnode.object_id} to #{self.object_id} (children: #{self.children.map(&:object_id)})"
      #logger.debug "Parent of #{wnode.object_id} is now #{wnode.parent.object_id}"
      self
    end
    alias :<< :add_child

    # Remove child to current node
    def remove_child(wnode)
      #logger.debug "Removing #{wnode.object_id} from #{self.children.map(&:object_id)}"
      wn = self.children.delete(wnode) do 
        logger.error "Couldn't find wnode ID #{wnode.object_id} (#{wnode})"
        raise
      end
      wn.parent = nil
      #logger.debug "Removed #{wnode.object_id} from #{self.object_id} (children: #{self.children.map(&:object_id)})"
      wn
    end
    alias :>> :remove_child
    
    # Reparent self node to another wnode
    def reparent_to(wnode)
      return if self.parent == wnode
      old_parent, new_parent = self.parent, wnode
      new_parent << self
      old_parent >> self
    end

    # insert a blank wnode above self, so between self wnode 
    # and its parent (self -> parent becomes self -> wn -> parent)
    def insert(wtype=:none)
      wn = WNode.new(wtype, self.parent)
      self.reparent_to(wn)
      wn
    end

    # Set this node class name
    def class_name=(class_name)
      @klass_name = class_name
    end

    # Find class name in this node and up the tree
    def class_name
      (cn = self.class_wnode) ? cn.klass_name : nil
    end

    def create_const(c_name, class_name, value, wtype)
      class_name ||= self.class_name
      if (cn = self.class_wnode)
        cn.consts << (const = Const.new(class_name, c_name, value, wtype))
      else
        raise "No class found for class constant #{const}"
      end
      const
    end

    # Look for constant in the appropriate class wnode
    # (it can be the current class or another class)
    def find_const(c_name, class_name=nil)
      if class_name
        wn_class = WNode.root.class_wnodes.find { |wn| wn.class_name == class_name}
      else
        wn_class   = self.class_wnode
        class_name = self.class_name
      end
      class_name ||= self.class_name
      logger.debug "looking for const #{c_name} in class #{class_name} at wnode #{self.class_wnode}..."
      wn_class.consts.find { |c| c.class_name == class_name && c.name == c_name }
    end

    def find_or_create_const(c_name, class_name, value, wtype)
      self.find_const(c_name, class_name) || self.create_const(c_name, class_name, value, wtype)
    end

    def create_cvar(cv_name, value=0, wtype=Type::I32)
      if (cn = self.class_wnode)
        logger.debug "creating cvar #{cv_name} in class #{self.class_name} at wnode #{self.class_wnode}..."
        cn.cvars << (cvar = Cvar.new(cn.klass_name, cv_name, value, wtype))
      else
        raise "No class found for class variable #{cvar}"
      end
      cvar
    end

    def find_cvar(cv_name)
      logger.debug "looking for cvar #{cv_name} in class #{self.class_name} at wnode #{self.class_wnode}..."
      self.class_wnode.cvars.find { |cv| cv.class_name == self.class_name && cv.name == cv_name }
    end

    def create_lvar(name)
      if (mn = self.method_wnode)
        mn.lvars << (lvar = Lvar.new(name))
      else
        raise "No method found for local variable #{name}"
      end
      lvar
    end

    def find_lvar(name)
      self.method_wnode.lvars.find { |lv| lv.name == name }
    end

    def find_or_create_lvar(name)
      self.find_lvar(name) || self.create_lvar(name)
    end

    # add method argument
    def create_marg(name)
      if (mn = self.method_wnode)
        mn.margs << (marg = Marg.new(name))
      else
        raise "No class found for class variable #{marg}"
      end
      marg
    end

    def find_marg(name)
      self.method_wnode.margs.find { |ma| ma.name == name }
    end

    def create_method(method_name, class_name=nil)
      if (cn = self.class_wnode)
        class_name ||= cn.klass_name
        cn.methods << (method = MEthod.new(method_name, class_name))
      else
        raise "No class wnode found for method creation #{method_name}"
      end
      method
    end

    def find_method(method_name, class_name=nil)
      class_name ||= self.class_wnode.klass_name
      self.class_wnode.methods.find { |m| m.name == method_name && m.class_name = class_name }
    end

    def find_or_create_method(method_name, class_name=nil)
      self.find_method(method_name, class_name) || self.create_method(method_name, class_name)
    end

    # Find block wnode up the tree
    def block_wnode
      if self.template == :block
        self
      else
        @parent ? @parent.block_wnode : nil
      end
    end

    # Find loop wnode up the tree
    def loop_wnode
      if self.template == :loop
        self
      else
        @parent ? @parent.loop_wnode : nil
      end
    end

    # Find class wnode up the tree
    def class_wnode
      if self.class?
        self
      else
        @parent ? @parent.class_wnode : nil
      end
    end

    # Find method wnode up the tree
    def method_wnode
      if self.method?
        self
      else
        @parent ? @parent.method_wnode : nil
      end
    end

    def func_name
      raise "Error: func_name is for :method wnode type only (got #{self.type})" \
        unless self.method?
      "$#{self.class_name}::#{@method.name}"
    end

    def in_method_scope?
      !self.method_wnode.nil?
    end

    def in_class_scope?
      !self.class_wnode.nil? && self.method_wnode.nil?
    end

    def in_root_scope?
      self.root? || self.parent.root?
    end

    def method?
      self.type == :method
    end

    def class?
      self.type == :class
    end

    # format the wnode and tree below
    # Note: this a just a tree dump. The output generated is
    # not valid WAT code 
    def to_s(indent=0)
      "\n%sw(%s:%s" % [' '*2*indent, self.type, self.wasm_code] + self.children.map { |wn| wn.to_s(indent+1) }.join('') + ')'
    end

    # Generate WAT code starting for this node and tree branches below
    def transpile(indent=0)
      case @type
      when :insn, :method
        if @template == :inline
          "\n%s%s" % [' '*2*indent, self.wasm_code]
        else
          "\n%s(%s" % [' '*2*indent, self.wasm_code] + self.children.map { |wn| wn.transpile(indent+1) }.join('') + ')'
        end
      when :root, :class, :none
        # no WAT code to generate for these nodes. Process children directly.
        self.children.map { |wn| wn.transpile(indent) }.join('')
      else
        raise "Error: Unknown wnode type #{@type}. No WAT code generated"
      end

    end
  end
end

