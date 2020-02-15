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
require_relative './klass'

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
      wattr_reader: %q{func %{func_name} (param $_self_ i32) (result %{wtype})
  (%{wtype}.load offset=%{offset} (local.get $_self_))},
      wattr_writer: %q{func %{func_name} (param $_self_ i32) (param %{wattr_name} %{wtype}) (result %{wtype})
  (local.get %{wattr_name})
  (%{wtype}.store offset=%{offset} (local.get $_self_) (local.get %{wattr_name}))},
      class_size: %q{func %{func_name} (result %{wtype})
  (%{wtype}.const %{size})}
    }

    attr_accessor :type, :wargs, :children, :parent, :comment, 
     :method, :template, :keep_on_stack, :classes
    attr_reader :wtype, :label, :klass

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
      @classes = [] # classes
      # top level class needed only if const are
      # defined at top level
      # NOTE: can't use create_klass as it find_class
      # which doesn't find root class ... endless loop!!
    
      # For class wnode only
      @@klass = nil
      self.klass = Klass.new(:Top__) if self.root?

      # For method wnode only
      @method = nil
      
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
      wargs = {}
      @wargs.each { |k, v| wargs[k] = (v.is_a?(Proc) ? v.call : v) }
      T[@template] ? T[@template] % wargs : ''
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
      logger.debug "Removing #{wnode.object_id} from #{self.children.map(&:object_id)}"
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
      logger.debug "Reparenting #{self.object_id} to #{wnode.object_id}"
      old_parent, new_parent = self.parent, wnode
      new_parent << self
      old_parent >> self if old_parent
    end

    # insert a blank wnode above self, so between self wnode 
    # and its parent (self -> parent becomes self -> wn -> parent)
    def insert(wtype=:none)
      wn = WNode.new(wtype, self.parent)
      self.reparent_to(wn)
      wn
    end

    def klass=(klass)
      @klass = klass
      @klass.wnode = self
      WNode.root.classes << klass
      klass
    end

    # Find class name in this node and up the tree
    def class_name
      (cn = self.class_wnode) ? cn.klass.name : nil
    end

    # Find class size in this wnode or up the tree
    def class_size
      (cn = self.class_wnode) ? cn.klass.size : nil
    end

    # Find the class object of the current and up the tree
    # if no name given or lookup the matching class from
    # the root level if class name given
    def find_class(class_name)
      logger.debug "looking for class #{class_name ? class_name : 'current'} 
        in scope #{self.scope} at wnode #{self}"
      if class_name
        c = WNode.root.classes.find { |c| 
          logger.debug "**** looking for class #{class_name} in class object #{c} / #{c.name}"; c.name == class_name }
      else
        if self.in_root_scope?
          # if at root level and no class name given
          # then it's the top level class
          c = self.class.root.klass
        else
          logger.debug "Looking for class wnode from wnode #{self} / ID: #{self.object_id} / 
          type: #{self.type} / class_wnode ID #{self.class_wnode.object_id} / 
          class_wnode #{self.class_wnode} /
          self klass : #{self.klass} / 
          self klass wtype : #{self.klass&.wtype} / "
          c = self.class_wnode.klass
        end
      end    
      if c
        logger.debug "Found class #{c.name} / #{c}"
      else
        logger.debug "Class #{class_name} not found"
      end
      c
    end

    # Create a Class object. **NOTE** the self
    # wnode must be the parent of the new class
    def create_class(class_name)
      wnc = WNode.new(:class, self)
      wnc.klass = Klass.new(class_name)
      logger.debug "Created class #{wnc.klass} under wnode #{self} / id: #{self.object_id}"
      wnc.klass
    end

    def find_or_create_class(class_name)
      self.find_class(class_name) || self.create_class(class_name)
    end

    # create a constant 
    def create_const(c_name, class_name, value, wtype)
      k = find_class(class_name)
      logger.debug "Creating constant #{c_name} in class #{k&.name} / wtype: #{wtype} at wnode #{self.class_wnode}..."
      if (cn = self.class_wnode)
        cn.klass.consts << (const = Const.new(k.name, c_name, value, wtype))
      else
        raise "No class found for class constant #{const}"
      end
      const
    end

    # Look for constant 
    def find_const(c_name, class_name=nil)
      logger.debug "looking for constant #{c_name} in class #{class_name ? class_name : 'current'} from wnode #{self}..."
      k = find_class(class_name)
      # Look for the constant both in current class and a roor class level
      const = [k, @@root.klass].map(&:consts).flatten.find do |c| 
        logger.debug "exploring constant #{c} / name: #{c.name} / class_name: #{c.class_name}";
        c.name == c_name
      end
      if const
        logger.debug "Constant #{c_name} found in class #{k.name} at wnode #{k.wnode}..."
      else
        logger.debug "Constant #{c_name} not found in class #{k.name} or at top level..."
      end
      const
    end

    def find_or_create_const(c_name, class_name, value, wtype)
      self.find_const(c_name, class_name) || self.create_const(c_name, class_name, value, wtype)
    end

    def find_wattr(wa_name, class_name=nil)
      k = find_class(class_name)
      raise "Can't find parent class for wattr #{wa_name}" unless k
      logger.debug "looking for wattr #{wa_name} in class #{k.name} at wnode #{self.class_wnode}..."
      k.wattrs.find { |wa| wa.class_name == k.name && wa.name == wa_name }
    end

    def create_wattr(wa_name, wtype=WType::DEFAULT)
      if (cn = self.class_wnode)
        logger.debug "creating wattr #{wa_name} in class #{self.class_name} at wnode #{self.class_wnode}..."
        cn.klass.wattrs << (wattr = WAttr.new(cn, wa_name, wtype))
      else
        raise "No class found for class attribute #{wa_name}"
      end
      wattr
    end

    def find_or_create_wattr(wa_name, class_name=nil, wtype=WType::DEFAULT)
      find_wattr(wa_name, class_name) || create_wattr(wa_name, wtype)
    end

    def create_ivar(iv_name, wtype=WType::DEFAULT)
      if (cn = self.class_wnode)
        logger.debug "creating ivar #{iv_name} in class #{self.class_name} at wnode #{self.class_wnode}..."
        cn.klass.wattrs << (wattr = WAttr.new(cn, iv_name, wtype))
      else
        raise "No class found for instance variable #{iv_name}"
      end
      wattr
    end

    def find_ivar(iv_name, class_name=nil)
      klass = find_class(class_name)
      raise "Can't find parent class for ivar #{iv_name}" unless klass
      logger.debug "looking for ivar #{iv_name} in class #{class_name} at wnode #{self.class_wnode}..."
      self.class_wnode.klass.wattrs.find { |wa| wa.ivar.class_name == klass.name && wa.ivar.name == iv_name }
    end

    def find_or_create_ivar(iv_name)
      self.find_ivar(iv_name) || self.create_ivar(iv_name)
    end

    def create_cvar(cv_name, value=0, wtype=WType::DEFAULT)
      if (cn = self.class_wnode)
        logger.debug "creating cvar #{cv_name} in class #{self.class_name} at wnode #{self.class_wnode}..."
        cn.klass.cvars << (cvar = CVar.new(cn.klass.name, cv_name, value, wtype))
      else
        raise "No class found for class variable #{cv_name}"
      end
      cvar
    end

    def find_cvar(cv_name)
      logger.debug "looking for cvar #{cv_name} in class #{self.class_name} at wnode #{self.class_wnode}..."
      self.class_wnode.klass.cvars.find { |cv| cv.class_name == self.class_name && cv.name == cv_name }
    end

    def create_lvar(name)
      if (mn = self.method_wnode)
        mn.method.lvars << (lvar = LVar.new(name))
      else
        raise "No method found for local variable #{name}"
      end
      lvar
    end

    def find_lvar(name)
      self.method_wnode.method.lvars.find { |lv| lv.name == name }
    end

    def find_or_create_lvar(name)
      self.find_lvar(name) || self.create_lvar(name)
    end

    # add method argument
    def create_marg(name)
      if (mn = self.method_wnode)
        mn.method.margs << (marg = MArg.new(name))
      else
        raise "No class found for class variable #{marg}"
      end
      marg
    end

    def find_marg(name)
      self.method_wnode.method.margs.find { |ma| ma.name == name }
    end

    # method_type is either :instance or :class
    def create_method(method_name, class_name, wtype, method_type)
      if (m = find_method(method_name, class_name, method_type))
        raise "MEthod already exists: #{m.inspect}"
      end
      if (cn = self.class_wnode)
        class_name ||= cn.klass.name
        cn.klass.methods << (method = MEthod.new(method_name, class_name, wtype))
      else
        raise "No class wnode found to create method #{method_name}"
      end
      method_type == :class ? method.class! : method.instance!
      logger.debug "Created MEthod: #{method}"
      method
    end

    # method_type is either :instance or :class
    def find_method(method_name, class_name, method_type)
      logger.debug "looking for method #{method_name} in class name #{class_name} from wnode #{self}"
      k = self.find_class(class_name)
      raise "Couldn't find class wnode for class_name #{class_name}" unless k
      if method_type == :class
        method = k.methods.find { |m| m.name == method_name && m.class_name == k.name && m.class? }
      elsif method_type == :instance
        method = k.methods.find { |m| m.name == method_name && m.class_name == k.name && m.instance? }
      else
        raise "Unknown method type : #{method_type.inspect}"
      end
      if method
        logger.debug "Found MEthod: #{method}"
      else
        logger.debug "Couldn't find MEthod: #{k.name},#{method_name}"
      end
      method
    end

    def find_or_create_method(method_name, class_name, wtype, method_type)
      wtype ||= WType::DEFAULT
      self.find_method(method_name, class_name, method_type) || \
      self.create_method(method_name, class_name, wtype, method_type)
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
      self.root? || (self.parent.root? && !in_class_scope?)
    end

    def method?
      self.type == :method
    end

    def class?
      self.type == :class || self.type == :root 
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

