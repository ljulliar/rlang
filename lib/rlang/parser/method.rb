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

    attr_reader :name, :wtype, :method_type, :wnode
    attr_writer :export_name
    attr_accessor :klass, :margs, :lvars, :export_as

    METHOD_TYPES = [:instance, :class]

    def initialize(name, klass, wtype, method_type)
      raise "Wrong method wtype argument: #{wtype.inspect}" unless wtype.is_a? WType
      @name = name
      @export_name = nil
      @klass = klass
      @wtype = wtype || WType::DEFAULT
      @method_type = method_type
      raise "Unknown method type: #{method_type}" unless METHOD_TYPES.include? @method_type
      @wnode = nil  # wnode where this method is implemented
      logger.debug "Method created #{name} in class #{klass.name} / ID:#{self}"
      @margs = []   # method args
      @lvars = []   # local variables
    end

    # Setup bidirectional links between
    # wnode and method
    def wnode=(wnode)
      @wnode = wnode
      wnode.method = self
    end

    def implemented?
      !@wnode.nil?
    end
    
    def instance!
      @method_type = :instance
    end

    def instance?
      @method_type == :instance

    end

    def class!
      @method_type = :class
    end

    def class?
      @method_type == :class
    end

    def wtype=(wtype)
      @wtype = wtype
      logger.debug "Method wtype updated: #{self}"
    end

    def wasm_name
      # [] method name is illegal in Wasm function name
      name = @name.to_s.sub(/\[\]/, 'brackets').to_sym
      if self.instance?
        "$#{@klass.path_name}##{name}"
      else
        "$#{@klass.path_name}::#{name}"
      end
    end

    def wasm_type
      @wtype.wasm_type
    end

    def export_name
      return @export_name if @export_name
      # [] method name is illegal in Wasm function name
      name = @name.to_s.sub(/\[\]/, 'brackets').to_sym
      if self.instance?
        "#{@klass.path_name.downcase}_i_#{name}"
      else
        "#{@klass.path_name.downcase}_c_#{name}"
      end
    end

    def export!(export_name=nil)
      @export_name = export_name
      Export.new(self)
    end

    def export_wasm_code
      '(export  "%s" (func %s))' % [self.export_name, self.wasm_name]
    end
  end
end