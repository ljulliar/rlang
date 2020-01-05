# Rubinius WebAssembly VM
# Copyright (c) 2019, Laurent Julliard and contributors
# All rights reserved.

# Local variables

require_relative './ext/type'

module Rlang::Parser
  class Lvar
    attr_reader :name, :wtype

    def initialize(name, wtype=Type::I32)
      @name = name
      # TODO: check if local/param value wtype
      # was explicitely declared
      @wtype = wtype
    end

    # TODO: factorize this code somewhere.
    # Also used in cvar, method and wgenerator
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
      "$#{name}"
    end

    def wasm_type
      @wtype.wasm_type
    end
  end
end