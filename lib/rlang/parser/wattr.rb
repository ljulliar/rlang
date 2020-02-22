# Rubinius WebAssembly VM
# Copyright (c) 2019, Laurent Julliard and contributors
# All rights reserved.

# Method argument class

require_relative '../../utils/log'
require_relative './ivar'
require_relative './wtype'

module Rlang::Parser
  class WAttr
    include Log
    attr_reader :name, :getter, :setter, :ivar

    # The name argument can either be the attribute name
    # (e.g. :size) or an ivar name (e.g. :@size)
    def initialize(class_wnode, name, wtype=WType::DEFAULT)
      @class_wnode = class_wnode
      @name = name
      @ivar = class_wnode.create_ivar(:"@#{name}", wtype)
      @getter = @class_wnode.find_or_create_method(self.getter_name, nil, wtype, :instance)
      logger.debug "Getter created: #{@getter.inspect}"
      @setter = @class_wnode.find_or_create_method(self.setter_name, nil, wtype, :instance)
      logger.debug "Setter created: #{@setter.inspect}"
      logger.debug "Class attribute #{name} created"
    end

    def class_name
      @class_wnode.class_name
    end

    def wtype
      @ivar.wtype
    end

    def offset
      @ivar.offset
    end
    
    def wtype=(wtype)
      # Adjust corresponding method objects wtype accordingly
      @getter.wtype = wtype
      @setter.wtype = wtype
      @ivar.wtype = wtype
      logger.debug "WAttr/Getter/Setter/ivar wtype updated : #{@getter.inspect}"
    end

    def getter_name
      @name
    end

    def setter_name
      "#{@name}=".to_sym
    end

    def wasm_name
      "$#{@name}"
    end
    
    def wasm_type
      self.wtype.wasm_type
    end
  end
end