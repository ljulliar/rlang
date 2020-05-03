# Rubinius WebAssembly VM
# Copyright (c) 2019, Laurent Julliard and contributors
# All rights reserved.

# Constant variables

require_relative './ext/type'
require_relative './cvar'

# Constants and Class variables are managed
# in exactly the same way
module Rlang::Parser
# Rubinius WebAssembly VM
# Copyright (c) 2019, Laurent Julliard and contributors
# All rights reserved.
#
# Class variables
# Note: Const class inherits from this class

require_relative '../../utils/log'
require_relative './wtype'
require_relative './data'

module Rlang::Parser
  class Const
    include Log
    attr_reader :scope_class, :name, :value
    attr_accessor :wtype

    def initialize(name, value, wtype=WType::DEFAULT)
      @scope_class = nil
      @name  = name
      @wtype = wtype
      @data  = nil
      self.value = value if value
    end

    # class or module in which constant is defined
    # not to be confused with wtype that hold the Rlang
    # class of the constant
    def scope_class=(scope_class_or_mod)
      logger.debug "Placing Constant #{name} in scope class #{scope_class_or_mod&.name}"
      raise "Error: constant scope class already initialized with #{scope_class.name} / #{@scope_class}. Got #{scope_class_or_mod.name} / #{scope_class_or_mod}." \
        if @scope_class
      @scope_class = scope_class_or_mod
      @scope_class.consts << self if @scope_class
    end

    # The value attribute can either be set at
    # initialize time or later (e.g. for classes and modules)
    def value=(value)
      # TODO: as opposed to Ruby we don't handle constant
      # reassignment for now.
      raise "Constant #{self.name} already initialized with value #{@value}. Now getting #{value}" \
        if @value
      return nil unless value
      logger.debug "Initializing constant #{@name} @ #{@address} with value #{@value} / wtype #{@wtype}"
      if value.kind_of? Module
         # for now just store 0 in constants
         # pointing to class or module
         # TODO: probably point to a minimal data 
         # with the class path string for instance (= class name)
        self.data = 0
      else
        self.data = value
      end
      @value = value
    end

    def data=(value)
      @data = DAta.new(self.path_name.to_sym, value, @wtype)
    end

    # the symbol form of this constant path
    # e.g. a constant A::B will return :"A::B"
    def path_name
      #@scope_class ? "#{@scope_class.path_name}::#{@name}".to_sym : @name
      self.path.map(&:name).join('::').to_sym
    end

    # Returns an array of successive Const objects that
    # altogether makes the full path of this Const
    # e.g. a constant A::B will return [Const(:A), Const(:B)]
    def path
      sk = nil; c = self; p = [c]
      while (sk = c.scope_class) && sk.const != c
        logger.debug "c: #{c.name}/#{c}, sk: #{sk.name}/#{sk}"
        c = sk.const
        p.unshift(c)
      end
      # Do not keep Object as the first element of the
      # const path unless it is the only element
      p.shift if p.first.name == :Object && p.size > 1
      logger.debug "Const#path : #{p.map(&:name)}"
      p
    end

    def class?
      @wtype.name == :Class
    end

    def module?
      @wtype.name == :Module
    end

    def address
      @data.address
    end

    def wasm_name
      "$#{self.path_name}"
    end

    def wasm_type
      @wtype.wasm_type
    end
  end
end
end
