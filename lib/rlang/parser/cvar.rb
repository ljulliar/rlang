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
  class CVar
    include Log
    attr_reader :name, :klass
    attr_accessor :wtype

    def initialize(klass, name, value=0, wtype=WType::DEFAULT)
      @klass = klass
      @name = name
      @wtype = wtype
      # Allocate and initialize the new cvar
      raise "Error: #{self.class} #{self.wasm_name} already created!" if DAta.exist? self.wasm_name.to_sym
      @data = DAta.new(self.wasm_name.to_sym, value, wtype) unless wtype.name == :Class
      logger.debug "creating #{self.class} #{self.class_name}::#{name} @ #{@address} with value #{value} / wtype #{wtype}"
    end

    def class_name
      @klass.name
    end

    def address
      @data.address
    end

    def value
      @data.value
    end

    def wasm_name
      "$#{@class_name}::#{@name}"
    end

    def wasm_type
      @wtype.wasm_type
    end
  end
end