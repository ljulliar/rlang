# Rubinius WebAssembly VM
# Copyright (c) 2019, Laurent Julliard and contributors
# All rights reserved.

# Method argument class

require_relative '../../utils/log'
require_relative './wtype'

module Rlang::Parser
  class WAttr
    include Log
    attr_reader :name, :wtype, :getter, :setter

    def initialize(class_wnode, name, wtype=WType::DEFAULT)
      @class_wnode = class_wnode
      @name = name
      @wtype = wtype
      # Also create the corresponding getter and setter
      # method objects (with default WType - wattr_type
      # directives might later change this wtype)
      # Don't generate WAT code yet
      @getter = @class_wnode.create_method(name)
      @getter.instance!
      @getter.wtype = wtype
      logger.debug "Getter created: #{@getter.inspect}"

      @setter = @class_wnode.create_method(:"#{name}=")
      @setter.instance!
      @setter.wtype = wtype
      logger.debug "Setter created: #{@setter.inspect}"

      logger.debug "Class attribute #{name} created"
    end

    def class_name
      @class_wnode.class_name
    end

    def wtype=(wtype)
      @wtype = wtype
      # Adjust corresponding method objects wtype accordingly
      @getter.wtype = wtype
      @setter.wtype = wtype
      logger.debug "Getter and Setter wtype updated : #{@getter.inspect}"
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