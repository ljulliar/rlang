# Rubinius WebAssembly VM
# Copyright (c) 2019, Laurent Julliard and contributors
# All rights reserved.

# Class variables

require_relative './ext/type'
require_relative './export'

module Rlang::Parser
  # Note: Cannot use Method as class name
  # because it's already used by Ruby
  class MEthod

    attr_reader :name, :wtype
    attr_accessor :class_name

    def initialize(name, class_name, wtype=Type::I32)
      @name = name
      @class_name = class_name
      @wtype = wtype
    end

    def wtype=(wtype)
      if wtype.is_a? Symbol
        if wtype == :none || wtype == nil
          @wtype =nil
        else
          @wtype = Type::ITYPE_MAP[wtype]
        end
      elsif wtype.nil? || wtype.ancestors.include?(Numeric)
        @wtype = wtype
      else
        raise "Error: unknown Type #{wtype}"
      end
    end

    def wasm_name
      "$#{@class_name}::#{@name}"
    end

    def wasm_type
      @wtype.wasm_type
    end

    def export_name
      "#{@class_name.downcase}_#{@name}"
    end

    def export!
      Export.new(self)
    end
  end
end