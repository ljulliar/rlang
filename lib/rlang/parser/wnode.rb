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
require_relative './attr'
require_relative './method'
require_relative './klass'
require_relative './module'

module Rlang::Parser
  class WNode
    include Log

    # WASM code templates
    T = {
      func: 'func %{func_name}',
      import: 'import "%{module_name}" "%{function_name}"',
      param: 'param %{name} %{wasm_type}',
      result: 'result %{wasm_type}',
      return: 'return',
      local: 'local %{name} %{wasm_type}',
      call: 'call %{func_name}',
      store: '%{wasm_type}.store',
      store_offset: '%{wasm_type}.store offset=%{offset}',
      load: '%{wasm_type}.load',
      load_offset: '%{wasm_type}.load offset=%{offset}',
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
      attr_getter: %q{func %{func_name} (param $_self_ i32) (result %{wtype})
  (%{wtype}.load offset=%{offset} (local.get $_self_))},
      attr_setter: %q{func %{func_name} (param $_self_ i32) (param %{attr_name} %{wtype}) (result %{wtype})
  (local.get %{attr_name})
  (%{wtype}.store offset=%{offset} (local.get $_self_) (local.get %{attr_name}))},
      class_size: %q{func %{func_name} (result %{wtype})
  (%{wtype}.const %{size})},
      comment: ';; %{comment}'
    }

    attr_accessor :type, :wargs, :children, :parent, :comment, 
                  :method, :template, :keep_on_stack, :classes,
                  :modules, :link
    attr_reader :wtype, :label, :klass, :module

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

      # top level class needed only if const are
      # defined at top level
      # NOTE: can't use create_klass as it find_class
      # which doesn't find root class ... endless loop!!
    
      # For class or module wnode only
      @klass = nil

      # For method wnode only
      @method = nil
      
      # For insn wnode with 
      # label (.e.g block, loop)
      @label = nil

      # link to a related node
      # Semantic of the link depend on the wnode type
      @link = nil
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
      logger.debug "Removing #{wnode.object_id} from wnodes list #{self.children.map(&:object_id)} under parent #{self.parent.object_id}"
      unless (wn = self.children.delete(wnode)) && wn == wnode
        raise "Couldn't find wnode ID #{wnode.object_id} (#{wnode})"
      end
      wn.parent = nil
      #logger.debug "Removed #{wnode.object_id} from #{self.object_id} (children: #{self.children.map(&:object_id)})"
      wnode
    end
    alias :>> :remove_child
    
    # Reparent self node to another wnode
    def reparent_to(wnode)
      unless self.parent == wnode
        logger.debug "Reparenting #{self.object_id} from #{self.parent.object_id} to #{wnode.object_id}"
        old_parent, new_parent = self.parent, wnode
        old_parent >> self if old_parent
        new_parent << self
      end
      self
    end

    # Reparent all children wnodes to another wnode
    # (in the same order)
    # WARNING!! Do not use self.children.each { } to
    # reparent because we are modifying children list
    # as we go
    def reparent_children_to(wnode)
      wnc = self.children
      wnc.count.times { wnc.first.reparent_to(wnode) }
      self
    end

    # insert a blank wnode above self, so between self wnode 
    # and its parent (self -> parent becomes self -> wn -> parent)
    def insert(type=:none)
      wn = WNode.new(type, self.parent)
      self.reparent_to(wn)
      wn
    end

    # delete current wnode (which means
    # basically remove it as a child)
    def delete!
      return if self.root? || self.parent.nil?
      self.parent.remove_child(self)
    end

    # Silence the current wnode (which means
    # inserting a silent type wnode between this
    # and its parent)
    def silence!
      self.insert(:silent)
    end

    def klass=(klass)
      @klass = klass
      @klass.wnode = self
      @klass
    end

    # Find class name in this node and up the tree
    def class_name
      (cn = self.class_wnode) ? cn.klass.path_name : nil
    end

    # Find class size in this wnode or up the tree
    def class_size
      (cn = self.class_wnode) ? cn.klass.size : nil
    end

    # Find the module object of the current wnode and up the tree
    # if no name given
    # or lookup the matching class from
    # the root level if module name given
    def find_module(module_path)
      logger.debug "looking for #{module_path} module in scope #{self.scope}" # at wnode #{self}"
      if modul = self.find_class_or_module_by_name(module_path)
        logger.debug "Found module #{modul.name} / #{modul}"
      else
        logger.debug "Module #{module_path} not found"
      end
      modul
    end

    # Create a module object
    def create_module(module_path)
      # Create the constant associated to this module
      klass = self.find_current_class_or_module()
      logger.debug "Creating module #{module_path} in class #{klass} under wnode #{self.head}"
      const = self.create_const(module_path, nil, WType.new(:Module))
      modul = Module.new(const, klass)
      # Add the constant to list of constants in current scope class
      klass.consts << const
      # Generate wnode
      wnc = WNode.new(:module, self)
      wnc.klass = modul
      logger.debug "Created module #{modul.name}/ID:#{modul} under wnode #{wnc.parent} / ID: #{self.object_id}"
      modul
    end

    def find_or_create_module(module_path)
      self.find_module(module_path) || self.create_module(module_path)
    end

    # Return the first class/module up the tree
    def find_current_class_or_module()
      logger.debug "looking for current class in scope #{self.scope}  at wnode #{self.head(3)}"
      if wn = self.class_or_module_wnode
        k = wn.klass
      elsif self.in_root_scope?
        # methods defined at root level goes to Object Class
        k = self.find_class_or_module_by_name([:Object])
      end
      if k
        logger.debug "Found class #{k.name} / #{k}"
      else
        logger.debug "No current class found!"
      end
      k
    end

    # Find the class by doing a lookup on the constant
    def find_class_or_module_by_name(class_path)
      raise "Class name argument expected" unless class_path && !class_path.empty?
      logger.debug "looking for class/module constant #{class_path} in scope #{self.scope} at wnode #{self.head}"
      const = self.find_const(class_path)
      #raise "Class or Module #{class_path} not found!" unless const
      if const
        logger.debug "Found constant #{const.name} pointing to #{const.value}"
        const.value
      else
        logger.debug "Constant #{class_path} not found"
        nil
      end
    end
      
    # Find the class object of the current and up the tree
    # if no name given or lookup the matching class from
    # the root level if class name given
    # class_path can be passed either as in a Symbol (e.g. :"A::B")
    # or as an array of symbols (e.g. [:A, :B])
    def find_class_or_module(class_path)
      logger.debug "looking for #{class_path} class in scope #{self.scope} at wnode #{self.head}"
      # turn the symbol form of class_path into the array form
      if class_path.is_a? Symbol
        class_path = class_path.to_s.split('::').map(&:to_sym)
      end

      if class_path.empty?
        k = self.find_current_class_or_module()
      else
        k = self.find_class_or_module_by_name(class_path)
      end
      if k
        logger.debug "Found class #{k.name} / #{k}"
      else
        logger.debug "Class #{class_path} not found!"
      end
      k
    end

    # Create a Class object. The code below assumes
    # the class doesn't exist
    def create_class(class_path, super_class_path)
      # check that super class exists
      super_class = nil
      unless super_class_path.empty?
        super_class_const = self.find_const(super_class_path)
        raise NameError, "uninitialized constant #{super_class_path}" \
          unless super_class_const
        super_class = super_class_const.scope_class
      end

      # Find current class or module (lexical scope)
      # special case for Object class
      if class_path == [:Object] && self.in_root_scope?
        scope_class = nil
      else
        scope_class = self.find_current_class_or_module()
      end

      # Create the constant associated to this class
      # the class itself
      const = self.create_const(class_path, nil, WType.new(:Class))
      k = Klass.new(const, scope_class, super_class)

      # special case to bootstrap Object class
      if class_path == [:Object] && self.in_root_scope?
        const.scope_class = k
      end

      # create class wnode
      wnc = WNode.new(:class, self)
      wnc.klass = k
      k.wnode = wnc
      logger.debug "Created class #{k.name}/ID: #{k} under wnode #{self}/ ID: #{self.object_id}"
      k
    end

    def find_or_create_class(class_path, super_class_path)
      logger.debug "Find/Create class: #{class_path}"
      if (km = self.find_class_or_module(class_path))
        raise TypeError, "#{class_path} is not a class" unless km.const.class?
      else
        km = self.create_class(class_path, super_class_path)
      end
      km
    end

    # create a constant, relative to the current wnode
    # the constant is assumed to not exist already
    def create_const(c_path, value, wtype)
      logger.debug "Creating constant #{c_path} / wtype: #{wtype} at wnode #{self.class_wnode.head}..."
      raise "Dynamic constant assignment. Constant #{name} cannot be created in scope #{cmn.scope}" \
        if self.in_method_scope?

      # if const_path has more than one element then check 
      # that all element but last already exist
      !(c_prefix = c_path[0..-2]).empty? && self.find_const(c_prefix)
      c_name = c_path.last
      const = Const.new(c_name, value, wtype)
    end

    # Look for constant from where we are in wtree
    # For a Ruby implementation of the constant lookup
    # algo, see https://cirw.in/blog/constant-lookup
    #  - c_path is an array of constant name elements
    #    e.g. for constant A::B::C constant_path is [A, B, C]
    def find_const(c_path)
      logger.debug "looking for constant #{c_path}...from wnode #{self.head}..."
      wn = self; idx = 0; count = c_path.size
      while idx < count
        const = wn._const_lookup(c_path[idx])
        if const && (idx < count-1) && (const.class? || const.module?) && const.scope_class
            wn = const.value.wnode
        else
          raise NameError, "uninitialized constant #{c_path.join('::')}" unless idx == count-1
        end
        idx += 1
      end
      const
    end

    def _const_lookup(name)
      # build constant lookup path: lexical scope first
      # excluding the 
      mn = self.find_current_class_or_module()&.nesting
      return nil unless mn
      # do not use find_class_... to find the Object class
      # This is to avoid and endless loop
      oc = WNode.root.klass 
      #oc = self.find_class_or_module_by_name([:Object])
      logger.debug "Module/Class nesting: #{mn.map(&:name)}"
      # and ancestors second
      lookup_path = mn + (mn.first || oc).ancestors
      lookup_path += oc.ancestors if (oc && mn.first.const.module?)
      logger.debug "searching constant #{name} in path #{lookup_path.map(&:name)}..."
      const = nil
      lookup_path.find do |mod|
        logger.debug "++ looking for const #{name} in #{mod.name}"
        const = mod.const_get(name)
      end
      if const
        logger.debug "... found! in class #{const.scope_class&.name}"
      else
        logger.debug "Constant #{name} not found in lookup path #{lookup_path.map(&:name)}..." \
      end
      const
    end

    # find or create constant, relative to current wnode
    def find_or_create_const(c_path, class_name, value, wtype)
      self.find_const(c_path) || self.create_const(c_path, value, wtype)
    end

    # find attr in current class
    def find_attr(name)
      k = self.find_current_class_or_module()
      raise "Can't find parent class for attr #{name}" unless k
      logger.debug "looking for attr #{name} in class #{k.name} at wnode #{self.class_wnode}..."
      k.attrs.find { |a| a.klass == k && a.name == name }
    end

    def create_attr(name, wtype=WType::DEFAULT)
      if (k = self.find_current_class_or_module())
        logger.debug "creating attr #{name} in class #{k.name} at wnode #{k.wnode}..."
        k.attrs << (_attr = Attr.new(k, name, wtype))
      else
        raise "No class found for class attribute #{name}"
      end
      _attr
    end

    # find or create attr in current class
    def find_or_create_attr(name, wtype=WType::DEFAULT)
      find_attr(name) || create_attr(name, wtype)
    end

    def create_ivar(iv_name, wtype=WType::DEFAULT)
      if (k = self.find_current_class_or_module())
        logger.debug "creating ivar #{iv_name} in class #{self.class_name} at wnode #{self.class_wnode}..."
        k.ivars << (ivar = IVar.new(k, iv_name, wtype))
      else
        raise "No class found for instance variable #{iv_name}"
      end
      ivar
    end

    def find_ivar(iv_name, class_name=nil)
      k = self.find_current_class_or_module()
      raise "Can't find parent class for ivar #{iv_name}" unless k
      logger.debug "looking for ivar #{iv_name} in class #{k.name} at wnode #{self.class_wnode}..."
      self.class_wnode.klass.ivars.find { |iv| iv.klass == k && iv.name == iv_name }
    end

    def find_or_create_ivar(iv_name)
      self.find_ivar(iv_name) || self.create_ivar(iv_name)
    end

    def create_cvar(cv_name, value=0, wtype=WType::DEFAULT)
      if (cn = self.class_wnode)
        logger.debug "creating cvar #{cv_name} in class #{self.class_name} at wnode #{self.class_wnode}..."
        cn.klass.cvars << (cvar = CVar.new(cn.klass, cv_name, value, wtype))
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
        raise "No class found for method argument #{marg}"
      end
      marg
    end

    def find_marg(name)
      self.method_wnode.method.margs.find { |ma| ma.name == name }
    end

    # method_type is either :instance or :class
    def create_method(klass, method_name, method_type, wtype, local=false)
      logger.debug "Create #{method_type} method #{method_name} in class #{class_name || 'current'} / wtype: #{wtype}"
      wtype ||= WType::DEFAULT

      # see if method already created
      m = find_method(klass, method_name, method_type, local)
      raise "Method already exists: #{class_name},#{m.name} / ID: #{m}" if m

      # Go create method
      km = klass || self.find_current_class_or_module()
      km.methods << (m = MEthod.new(method_name, km, wtype, method_type))
      logger.debug "++++ adding #{method_type} method #{m.name}/ID:#{m} in class #{km.name}/ID:#{km}"
      logger.debug "#{km.methods.count} methods in class #{km.name}/#{km}"
      m
    end

    # method_type is either :instance or :class
    # if local is true look for method in the current class only
    def find_method(klass, method_name, method_type, local=false)
      logger.debug "looking #{local ? 'locally' : 'globally'} for #{method_type} method #{method_name} in class #{klass}" #from wnode #{self.head(2)}"
      km = klass || self.find_current_class_or_module()
      raise "Couldn't find scope class/module where to search for method #{method_name}" unless km

      class_hierarchy = (local ? [km] : km.ancestors)
      logger.debug "searching #{method_type} method #{method_name} in ancestors #{class_hierarchy.map(&:name)}..."
      method = nil
      class_hierarchy.each do |k|
        logger.debug "Currently #{k.methods.count} method(s) in class #{k.name}/#{k}"
        method = k.methods.find do |m| 
          logger.debug "++ looking for #{method_type} method #{k.name}/#{method_name} in #{m.klass.name}/#{m.name}/#{m.method_type}"
          m.name == method_name && m.klass == k && m.method_type == method_type
        end
        break if method
      end
      if method
        logger.debug "Found #{method_type} method: #{km.name},#{method.name} in #{method.klass.name}"
      else
        logger.debug "Couldn't find #{method_type} method: #{km.name},#{method_name}"
      end
      method
    end

    def find_or_create_method(klass, method_name, method_type, wtype, local=false)
      self.find_method(klass, method_name, method_type, local) || 
      self.create_method(klass, method_name, method_type, wtype, local)
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

    # Find module wnode up the tree
    def module_wnode
      if self.module?
        self
      else
        @parent ? @parent.module_wnode : nil
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

    # Find class or module wnode up the tree
    # which ever come first
    def class_or_module_wnode
      if self.class? || self.module?
        self
      else
        @parent ? @parent.class_or_module_wnode : nil
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
      return :module if self.in_module_scope?
      return :root if self.in_root_scope?
    end

    def in_method_scope?
      !self.method_wnode.nil?
    end

    def in_class_method_scope?
      self.in_method_scope? && self.method_wnode.method.class?
    end

    def in_instance_method_scope?
      self.in_method_scope? && self.method_wnode.method.instance?
    end

    def in_class_scope?
      !self.class_wnode.nil? && !self.in_method_scope?
    end

    def in_module_scope?
      !self.module_wnode.nil? && !self.in_method_scope?
    end

    def in_class_or_module_scope?
      self.in_class_scope? || self.in_module_scope?
    end

    def in_root_scope?
      self.root? || (self.parent.root? && !self.in_class_scope?)
    end

    def method?
      self.type == :method
    end

    def class?
      # root always has the Object class associated
      self.type == :class || self.type == :root 
    end

    def module?
      self.type == :module
    end

    # format the wnode and tree below
    # Note: this a just a tree dump. The output generated is
    # not valid WAT code 
    def to_s(indent=0)
      "\n%sw(%s:%s" % [' '*2*indent, self.type, self.wasm_code] + self.children.map { |wn| wn.to_s(indent+1) }.join('') + ')'
    end

    def head(n=5)
      (self.to_s.lines[0,n] << "...\n").join('')
    end

    # Generate WAT code starting for this node and tree branches below
    def transpile(indent=0)
      # follow children first and then go on with
      # the wnode link if it exits
      children = self.children + (self.link ? [self.link] : [])

      logger.debug "children: #{self} / #{children.map(&:head)}" if self.link

      case @type
      # Section nodes  
      when :imports
        "\n%s;;============= %s SECTION ===============\n" % [' '*2*indent, @type.to_s.upcase] +
        children.map { |wn| wn.transpile(indent) }.join('')
      when :data
        "\n\n%s;;============= %s SECTION ===============\n" % [' '*2*indent, @type.to_s.upcase] +
        DAta.transpile
      when :globals
        "\n\n%s;;============= %s SECTION ===============\n" % [' '*2*indent, @type.to_s.upcase] +
        Global.transpile
      when :exports
        "\n\n%s;;============= %s SECTION ===============\n" % [' '*2*indent, @type.to_s.upcase] +
        Export.transpile        
      when :insn, :method
        if @template == :inline
          "\n%s%s" % [' '*2*indent, self.wasm_code]
        else
          "\n%s(%s" % [' '*2*indent, self.wasm_code] + children.map { |wn| wn.transpile(indent+1) }.join('') + ')'
        end
      when :root, :class, :module, :none
        # no WAT code to generate for these nodes. Process children directly.
        children.map { |wn| wn.transpile(indent) }.join('')
      when :silent
        # Do not generate any WAT code for a silent node and
        # and its children
        ''
      else
        raise "Error: Unknown wnode type #{@type}. No WAT code generated"
      end

    end
  end
end

