# Rubinius WebAssembly VM
# Copyright (c) 2019, Laurent Julliard and contributors
# All rights reserved.
#
# Instance variables class
#
require_relative '../../utils/log'
require_relative './wtype'
require_relative './data'

module Rlang::Parser
  class IVar
    include Log
    attr_reader :name, :klass
    attr_accessor :wtype, :offset

    def initialize(klass, name, wtype=WType::DEFAULT)
      @klass = klass
      @name = name
      @wtype = wtype
      # this is the offset of the instance variable
      # in memory in the order they are declared
      # It is computed at the end of a class
      # definition
      @offset = nil
      logger.debug "Instance variable #{name} created"
    end

    def size
      @wtype.size
    end

    def wasm_name
      "$#{@name}"
    end

    def wasm_type
      @wtype.wasm_type
    end
  end
end