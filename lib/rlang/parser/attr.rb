# Rlang language, compiler and libraries
# Copyright (c) 2019-2022,Laurent Julliard and contributors
# All rights reserved.

# Method argument class

require_relative '../../utils/log'
require_relative './ivar'
require_relative './wtype'

module Rlang::Parser
  class Attr
    include Log
    attr_reader :name, :getter, :setter, :ivar, :klass

    # The name argument can either be the attribute name
    # (e.g. :size) or an ivar name (e.g. :@size)
    def initialize(klass, name, wtype=WType::DEFAULT)
      @klass = klass
      @name = name
      @ivar = klass.wnode.create_ivar(:"@#{name}", wtype)
      @getter = nil
      @setter = nil
      @export = false
      logger.debug "Class attribute #{name} created"
    end

    def attr_reader
      @getter = @klass.wnode.find_or_create_method(nil, self.getter_name, :instance, wtype)
      @getter.export! if @export
      logger.debug "Getter created: #{@getter}"
      @getter
    end

    def attr_writer
      @setter = @klass.wnode.find_or_create_method(nil, self.setter_name, :instance, wtype)
      @setter.export! if @export
      logger.debug "Setter created: #{@setter}"
      @setter
    end

    def attr_accessor
      [self.attr_reader, self.attr_writer]
    end

    def export!
      @export = true
    end

    def wtype
      @ivar.wtype
    end

    def offset
      @ivar.offset
    end
    
    def wtype=(wtype)
      # Adjust getter/setter and ivar wtype accordingly
      @getter.wtype = wtype if @getter
      @setter.wtype = wtype if @setter
      @ivar.wtype = wtype
      logger.debug "Attr/Getter/Setter/ivar wtype updated : #{@getter}"
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