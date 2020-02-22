# Rubinius WebAssembly VM
# Copyright (c) 2019, Laurent Julliard and contributors
# All rights reserved.

# Rlang classes
require_relative '../../utils/log'
require_relative './wtype'

module Rlang::Parser
  # Note: Cannot use Class as class name
  # because it's already used by Ruby
  class Klass
    include Log

    attr_reader :wtype
    attr_accessor :name, :wnode, :wattrs, :ivars, :cvars, 
                  :consts, :methods, :offset

    def initialize(name)
      @name = name
      # the type of a class is its name by definition
      @wtype = WType.new(name)
      @size = 0
      # the wnode implementing the code of the class
      @wnode = nil
      logger.debug "Klass created #{self.inspect}"
      @wattrs  = [] # class attributes
      @ivars   = [] # instance variables
      @cvars   = [] # class variables
      @consts  = [] # class constants
      @methods = [] # methods
      @offset  = 0  # offset of the next class attribute in memory
    end

    def size
      @offset
    end

    def wtype=(wtype)
      @wtype = wtype
      logger.debug "Klass #{@name} wtype updated: #{self.inspect}"
    end

    def wasm_name
      @name
    end

    def wasm_type
      @wtype.wasm_type
    end
  end
end