# Rubinius WebAssembly VM
# Copyright (c) 2019, Laurent Julliard and contributors
# All rights reserved.

require_relative '../../utils/log'
require_relative '../ext/tempfile'
require_relative './renderer'

module Builder::Wat
  class Builder
    include Log

    @@wat_compiler = 'wat2wasm'

    attr_reader :target, :source

    def initialize(source, target)
      check_compiler
      @source = source
      if target
        @target = target
      else
        @target = @source.gsub(/\.wat$/,'.wasm')
        @temp_target = true
      end
      logger.debug "Wat Builder Source: #{@source}"
      logger.debug "Wat Builder Target: #{@target}"
    end

    def check_compiler
      raise "wat2wasm compiler not found. Make sure it is in your PATH" \
        unless system("#{@@wat_compiler} --help >/dev/null")
    end

    def compile
      system("#{@@wat_compiler} #{@source} -o #{@target}")
    end

    def cleanup
      File.unlink(@target) if @temp_target
    end
  end
end
