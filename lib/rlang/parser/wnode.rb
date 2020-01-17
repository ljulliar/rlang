# Rubinius WebAssembly VM
# Copyright (c) 2019, Laurent Julliard and contributors
# All rights reserved.
#
# Nodes used to generate WASM code 

require_relative  '../../utils/log'
require_relative './wtype'
require_relative './const'
require_relative './cvar'
require_relative './lvar'
require_relative './wattr'
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
      addr: 'i32.const %{value}',
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
      wattr_reader: %q{func %{func_name} (param $_ptr_ i32) (result %{wtype})
  (%{wtype}.load offset=%{offset} (local.get $_ptr_))},
      wattr_writer: %q{func %{func_name} (param $_ptr_ i32) (param %{wattr_name} %{wtype}) (result %{wtype})
  (local.get %{wattr_name})
  (%{wtype}.store offset=%{offset} (local.get $_ptr_) (local.get %{wattr_name}))},
  #(%{wtype}.load offset=%{offset} (local.get $_ptr_))},
      class_size: %q{func %{func_name} (result %{wtype})
  (%{wtype}.const %{size})}
    }

    attr_accessor :type, :wargs, :children, :parent, :comment, :lvars, :cvars, :margs,
                  :consts, :methods, :method, :template, :keep_on_stack,
                  :class_wnodes
    attr_reader   :wtype, :label, :klass_name, :klass_size, :wattrs

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
      @wtype = WType::DEFAULT

      # For root wnode
      @class_wnodes = [] # wnodes of classes

      # For class wnode only
      @klass_name = nil
      @wattrs  = [] # class attributes
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

    # Says whether this wnode produces a straight
    # WASM const node in the end
    def const?
      self.template == :const || self.template == :addr
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
    end

    def wasm_code
      @wargs[:wasm_type] ||= self.wasm_type
      T[@template] ? T[@template] % @wargs : ''
    end

    def wasm_type
      @wtype.wasm_type
    end
    
    def set_label
      @label = "$lbl_#{'%02d' % (@@label_index += 1)}"
    end

    # Specify the WASM type of this node
    def wtype=(wtype)
      raise "Expecting a WType argument (got #{wtype.inspect}" unless wtype.is_a? WType
      logger.debug "Setting wtype #{wtype} for wnode #{self}"
      @wtype = wtype
      @method.wtype = @wtype if self.method?
      # update wasm_type template arg accordingly
      @wargs[:wasm_type] = @wtype.wasm_type if @wtype
      logger.debug "type #{self.type} wargs #{self.wargs} wtype #{@wtype}"
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

    # Find class name in this node and up the tree
    def class_size
      (cn = self.class_wnode) ? cn.wattrs.sum(&:size) : nil
    end

    # Find the class wnode matching with the given
    # class name
    def find_class(class_name=nil)
      if class_name
        WNode.root.class_wnodes.find { |wn| wn.class_name == class_name }
      else
        self.class_wnode
      end     
    end

    # create a constant 
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
      wn_class = find_class(class_name)
      raise "Can't find parent class for constant #{c_name}" unless wn_class
      class_name = wn_class.class_name
      logger.debug "looking for const #{c_name} in class #{class_name} at wnode #{self.class_wnode}..."
      wn_class.consts.find { |c| c.class_name == class_name && c.name == c_name }
    end

    def find_or_create_const(c_name, class_name, value, wtype)
      self.find_const(c_name, class_name) || self.create_const(c_name, class_name, value, wtype)
    end

    def find_wattr(wa_name, class_name=nil)
      wn_class = find_class(class_name)
      raise "Can't find parent class for wattr #{wa_name}" unless wn_class
      class_name = wn_class.class_name
      logger.debug "looking for wattr #{wa_name} in class #{class_name} at wnode #{self.class_wnode}..."
      wn_class.wattrs.find { |wa| wa.class_name == class_name && wa.name == wa_name }
    end

    def create_wattr(wa_name, wtype=WType::DEFAULT)
      if (cn = self.class_wnode)
        logger.debug "creating wattr #{wa_name} in class #{self.class_name} at wnode #{self.class_wnode}..."
        cn.wattrs << (wattr = WAttr.new(cn, wa_name, wtype))
      else
        raise "No class found for class attribute #{wa_name}"
      end
      wattr
    end

    def create_cvar(cv_name, value=0, wtype=WType::DEFAULT)
      if (cn = self.class_wnode)
        logger.debug "creating cvar #{cv_name} in class #{self.class_name} at wnode #{self.class_wnode}..."
        cn.cvars << (cvar = CVar.new(cn.klass_name, cv_name, value, wtype))
      else
        raise "No class found for class variable #{cv_name}"
      end
      cvar
    end

    def find_cvar(cv_name)
      logger.debug "looking for cvar #{cv_name} in class #{self.class_name} at wnode #{self.class_wnode}..."
      self.class_wnode.cvars.find { |cv| cv.class_name == self.class_name && cv.name == cv_name }
    end

    def create_lvar(name)
      if (mn = self.method_wnode)
        mn.lvars << (lvar = LVar.new(name))
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
        mn.margs << (marg = MArg.new(name))
      else
        raise "No class found for class variable #{marg}"
      end
      marg
    end

    def find_marg(name)
      self.method_wnode.margs.find { |ma| ma.name == name }
    end

    def create_method(method_name, class_name=nil, wtype=WType::DEFAULT)
      raise "MEthod already exists: #{m}" \
        if (m = find_method(method_name, class_name))
      if (cn = self.class_wnode)
        class_name ||= cn.klass_name
        cn.methods << (method = MEthod.new(method_name, class_name, wtype))
      else
        raise "No class wnode found to create method #{method_name}"
      end
      logger.debug "Created MEthod: #{method.inspect}"
      method
    end

    def find_method(method_name, class_name=nil)
      if class_name
        class_wnode = find_class(class_name)
      else
        class_wnode = self.class_wnode
      end
      raise "Couldn't find class wnode for class_name #{class_name}" unless class_wnode
      class_name = class_wnode.klass_name
      method = class_wnode.methods.find { |m| m.name == method_name && m.class_name = class_name }
      if method
        logger.debug "Found MEthod: #{method.inspect}"
      else
        logger.debug "Couldn't find MEthod: #{class_name.inspect},#{method_name.inspect}"
      end
      method
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

    def scope
      return :class_method if self.in_class_method_scope?
      return :instance_method if self.in_instance_method_scope?
      return :class if self.in_class_scope?
      return :root if self.in_root_scope?
    end

    def in_method_scope?
      !self.method_wnode.nil?
    end

    def in_class_method_scope?
      !self.method_wnode.nil? && !self.method_wnode.method.instance?
    end

    def in_instance_method_scope?
      !self.method_wnode.nil? && self.method_wnode.method.instance?
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

