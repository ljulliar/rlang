require_relative './ext/type'

module Rlang::Parser
  class Export
    @@exports = []
    TMPL = '(export  "%s" (func %s))' 
    attr_reader :method
    
    def initialize(method)
      @method = method
      @@exports << self
    end

    def self.transpile
      @@exports.collect do |export|
        TMPL % [export.method.export_name, export.method.wasm_name]
      end.join("\n")
    end
  end
end