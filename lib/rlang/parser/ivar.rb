# Rubinius WebAssembly VM
# Copyright (c) 2019, Laurent Julliard and contributors
# All rights reserved.
#
# Instance variables
#
require_relative '../../utils/log'
require_relative './wtype'
require_relative './data'

module Rlang::Parser
  class IVar
    include Log
    attr_reader :name, :class_wnode
    attr_accessor :wtype

    def initialize(class_wnode, name, wtype=WType::DEFAULT)
      @name = name
      @class_wnode = class_wnode
      @wtype = wtype
      logger.debug "creating instance variable #{name} in class #{self.class_name} / wtype #{wtype}"
    end

    def class_name
      @class_wnode.class_name
    end

    def wattr_name
      @name.to_s.tr('@','').to_sym
    end

    def wasm_type
      @wtype.wasm_type
    end
  end
end