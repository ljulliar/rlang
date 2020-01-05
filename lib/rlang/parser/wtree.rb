# Rubinius WebAssembly VM
# Copyright (c) 2019, Laurent Julliard and contributors
# All rights reserved.
#
# Node tree structure supporting the construction
# of the WASM Abstract Syntax Tree

require_relative './wnode'

module Rlang::Parser
  class WTree
    attr_reader :root

    def initialize
      @root = WNode.new(:root)
    end
  end
end

