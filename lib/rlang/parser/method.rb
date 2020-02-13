# Rubinius WebAssembly VM
# Copyright (c) 2019, Laurent Julliard and contributors
# All rights reserved.

# Rlang methods
require_relative '../../utils/log'
require_relative './wtype'
require_relative './export'

module Rlang::Parser
  # Note: Cannot use Method as class name
  # because it's already used by Ruby
  class MEthod
    include Log

    attr_reader :name, :wtype
    attr_accessor :class_name, :margs, :lvars, :wnode

    def initialize(name, class_name, wtype=WType::DEFAULT)
      raise "Wrong method wtype argument: #{wtype.inspect}" unless wtype.is_a? WType
      @name = name
      @class_name = class_name
      @wtype = wtype
      @instance = false
      @wnode = nil # wnode where method is implemented
      logger.debug "Method created #{self.inspect}"
      @margs = []   # method args
      @lvars = []   # local variables
    end

    def instance!
      @instance = true
    end

    def instance?
      @instance
    end

    def class!
      @instance = false
    end

    def class?
      !@instance
    end

    def wtype=(wtype)
      @wtype = wtype
      logger.debug "Method wtype updated: #{self}"
    end

    def wasm_name
      if @instance
        "$#{@class_name}##{@name}"
      else
        "$#{@class_name}::#{@name}"
      end
    end

    def wasm_type
      @wtype.wasm_type
    end

    def export_name
      if @instance
        "#{@class_name.downcase}_i_#{@name}"
      else
        "#{@class_name.downcase}_c_#{@name}"
      end
    end

    def export!
      Export.new(self)
    end

    def export_wasm_code
      '(export  "%s" (func %s))' % [self.export_name, self.wasm_name]
    end
  end
end