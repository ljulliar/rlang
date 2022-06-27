# Rlang language, compiler and libraries
# Copyright (c) 2019-2022,Laurent Julliard and contributors
# All rights reserved.

# Class variables

require_relative './wtype'
require_relative './export'

module Rlang::Parser
  class Global
    @@globals = []
    attr_accessor :name, :wtype, :mutable, :value

    def initialize(name, wtype=WType::DEFAULT, value=0, mutable=true)
      @name = name
      @wtype = wtype
      @mutable = mutable
      @value = value
      @@globals << self
    end

    def self.find(name)
      @@globals.find {|g| g.name == name}
    end

    def self.reset!
      @@globals = []
    end

    def mutable?
      @mutable
    end

    def wasm_name
      @name
    end

    def wasm_type
      @wtype.wasm_type
    end

    def export_name
      @name
    end

    def export!
      Export.new(self)
    end

    def export_wasm_code
      '(export  "%s" (global %s (mut %s)))' % [self.export_name, self.wasm_name, self.wtype.wasm_type]
    end

    def self.transpile(depth)
      # TODO : we should probably do that in a less "hardcoded" way
      # Adjust the Heap base address to start after the static DAta
      # section
      g_heap = Global.find(:$HEAP)
      g_heap.value = [DAta.align(8), g_heap.value].max if g_heap
      
      # Go generate code now
      indent = ' ' * depth * 2
      output = []
      @@globals.each do |g|
        if g.mutable?
          output << '(global %{name} (mut %{type}) (%{type}.const %{value}))' \
                    % {name: g.wasm_name, type: g.wtype.wasm_type, value: g.value}
        else
          output << '(global %{name} %{type} (%{type}.const %{value}))' \
                    % {name: g.wasm_name, type: g.wtype.wasm_type, value: g.value}
        end
      end
      indent + output.join("\n#{indent}")
    end
  end
end