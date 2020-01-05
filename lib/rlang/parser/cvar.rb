# Rubinius WebAssembly VM
# Copyright (c) 2019, Laurent Julliard and contributors
# All rights reserved.
#
# Class variables
# Note: Const class inherits from this class

require_relative '../../utils/log'
require_relative './ext/type'
require_relative './data'

module Rlang::Parser
  class Cvar
    include Log
    attr_reader :name, :wtype, :class_name

    def initialize(class_name, name, value=0, wtype=Type::I32)
      @name = name
      @class_name = class_name
      @wtype = wtype
      # Allocate and initialize the new cvar
      raise "Error: Class variable #{self.wasm_name} already created!" if DAta.exist? self.wasm_name.to_sym
      @data = DAta.new(self.wasm_name.to_sym, value, wtype)
      logger.debug "creating #{self.class} #{class_name}::#{name} @ #{@address} with value #{value} / wtype #{wtype}"
    end

    def address
      @data.address
    end

    def value
      @data.value
    end

    def wtype=(wtype)
      if wtype.is_a? Symbol
        @wtype = Type::ITYPE_MAP(wtype)
      elsif wtype.nil? || wtype.ancestors.include?(Numeric)
        @wtype = wtype
      else
        raise "Error: unknown Type #{wtype}"
      end
    end

    def wasm_name
      "$#{@class_name}::#{@name}"
    end

    def wasm_type
      @wtype.wasm_type
    end
  end
end