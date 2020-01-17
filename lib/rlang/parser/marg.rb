# Rubinius WebAssembly VM
# Copyright (c) 2019, Laurent Julliard and contributors
# All rights reserved.

# Method argument class

require_relative '../../utils/log'
require_relative './wtype'

module Rlang::Parser
  class MArg
    include Log
    attr_reader :name
    attr_accessor :wtype

    def initialize(name, wtype=WType::DEFAULT)
      @name = name
      @wtype = wtype
      logger.debug "Method argument #{name} created"
    end

    def wasm_name
      "$#{@name}"
    end

    def wasm_type
      @wtype.wasm_type
    end
  end
end