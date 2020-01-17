# Rubinius WebAssembly VM
# Copyright (c) 2019, Laurent Julliard and contributors
# All rights reserved.

# Local variables

require_relative './wtype'

module Rlang::Parser
  class LVar
    attr_reader :name
    attr_accessor :wtype

    def initialize(name, wtype=WType::DEFAULT)
      @name = name
      # TODO: check if local/param value wtype
      # was explicitely declared
      @wtype = wtype
    end

    def wasm_name
      "$#{name}"
    end

    def wasm_type
      @wtype.wasm_type
    end
  end
end