require_relative './ext/type'

module Rlang::Parser
  class Export
    @@exports = []
    attr_reader :object
    
    # Object can be either a method object or a global object
    def initialize(object)
      @object = object
      @@exports << self
    end

    def self.reset!
      @@exports = []
    end

    # Export Rlang funcs, etc... grouping them
    # by object type for Wasm code readability
    def self.transpile
      @@exports.sort_by {|e| e.object.class.to_s}.collect do |export|
        export.object.export_wasm_code
      end.join("\n")
    end
  end
end