# Rubinius WebAssembly VM
# Copyright (c) 2019, Laurent Julliard and contributors
# All rights reserved.

require_relative '../ext/tempfile'

module Builder::Rlang
  class Builder

    # Rlang to WAT compiler
    RLANG_COMPILER = File.expand_path('../../../../bin/rlang', __FILE__)

    attr_reader :source, :target, :wat_path

    def initialize
      check_compiler
      @wat_path = nil
      @target = nil
    end

    def check_compiler
      raise "no rlang compiler found" unless File.exist? RLANG_COMPILER
    end

    def compile(source, target, options='')
      @source = source # Path to Rlang file
      @target = target
      @options = options
      system("#{RLANG_COMPILER} #{@options} --wasm -o #{target} #{@source}")
    end

    def cleanup
      File.unlink(@target) if @target
    end
  end
end
