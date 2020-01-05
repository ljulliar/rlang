# Rubinius WebAssembly VM
# Copyright (c) 2019, Laurent Julliard and contributors
# All rights reserved.

# Method argument class

require_relative '../../utils/log'
require_relative './ext/type'

module Rlang::Parser
  class Marg
    include Log
    attr_reader :name, :wtype

    def initialize(name, wtype=Type::I32)
      @name = name
      self.wtype = wtype
      logger.debug "Method argument #{name} created"
    end

    def wtype=(wtype)
      if wtype.is_a? Symbol
        @wtype = Type::ITYPE_MAP[wtype]
      elsif wtype.nil? || wtype.ancestors.include?(Numeric)
        @wtype = wtype
      else
        raise "Error: unknown Type #{wtype}"
      end
    end

    def wasm_name
      "$#{@name}"
    end

    def wasm_type
      @wtype.wasm_type
    end
  end
end