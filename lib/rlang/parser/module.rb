# Rubinius WebAssembly VM
# Copyright (c) 2019, Laurent Julliard and contributors
# All rights reserved.

# Rlang classes
require_relative '../../utils/log'
require_relative './const'

module Rlang::Parser
  class Module
    include Log

    attr_reader   :wtype, :const
    attr_accessor :wnode, :attrs, :ivars, :cvars, 
                  :consts, :methods, :offset,
                  :includes, :extends

    def initialize(const, scope_class)
      @const = const
      # upper lexical class or module
      logger.debug "scope_class: #{scope_class}"
      @const.scope_class = scope_class
      # the wtype of a Class/Module is either :Class or :Module
      @wtype = WType.new(@const.path_name)
      # memory space used by ivars in bytes
      @size = 0
      # the wnode implementing the code of the class
      @wnode = nil
      @super_class = nil
      @attrs     = [] # class attributes
      @ivars     = [] # instance variables
      @cvars     = [] # class variables
      # Note: the consts list is fed from the Const class
      # on purpose so that it applies to any constant not jus
      # Classes and modules
      @consts    = [] # class constants
      @methods   = [] # methods
      @offset    = 0  # memory offset of next ivar

      # Modules included/extended/prepended in 
      # this module/class
      @modules   = [] # all modules included, prepended, extended
      @includes  = [] # modules included
      @prepends  = [] # modules prepended
      @extends   = [] # modules extended

      # Is this module extended, included, prepended ?
      @extended  = false
      @included  = false
      @prepended = false

      # Associated constant/value points to the class/module
      @const.value = self
      logger.debug "Created Class/Module #{@const} / #{self}"
    end

    def object_class?
      self.const.name == :Object && self.const.scope_class == self
    end

    def name
      @const.name
    end

    def path
      @const.path
    end

    def path_name
      @const.path_name
    end

    # Do not include the top class Object in nesting
    def nesting
      sk = nil; k = self; n = [k]
      while (sk = k.const.scope_class) && (sk != k) && !sk.object_class?
        logger.debug "k: #{k.name}/#{k}, sk: #{sk.name}/#{sk}, sk.object_class? #{sk.object_class?}"
        n.unshift(sk)
        k = sk
      end
      logger.debug "Class#nesting : #{n.map(&:name)}"
      n
    end

    def include(klass)
      @modules   |= [klass]
      @includes  |= [klass]
    end

    def prepend(klass)
      @modules   |= [klass]
      @prepends  |= [klass]
    end

    def extend(klass)
      @modules   |= [klass]
      @extends   |= [klass]
    end

    def ancestors
      @prepends.reverse + [self] + @includes.reverse + @extends.reverse + \
        (@super_class ? @super_class.ancestors : [])
    end

    def const_get(name)
      consts.find { |c| c.name == name}
    end

    def delete_instance_methods
      @methods.select { |m| m.instance? }.each { |m| m.wnode.delete!; @methods.delete(m) }
    end

    def delete_class_methods
      self.methods.select { |m| m.class? }.each { |m| m.wnode.delete!; @methods.delete(m) }
    end

    def size
      @offset
    end

    def wtype=(wtype)
      @wtype = wtype
      logger.debug "#{self.class} #{@name} wtype updated: #{self.inspect}"
    end

    def wasm_name
      @name
    end

    def wasm_type
      @wtype.wasm_type
    end

    def extended?; @extended; end
    def extended!; @extended = true; end

    def included?; @included; end
    def included!; @included = true; end

    def prepended?; @prepended; end
    def prepended!; @prepended = true; end
  end
end