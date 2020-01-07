# Rubinius WebAssembly VM
# Copyright (c) 2019, Laurent Julliard and contributors
# All rights reserved.

require_relative '../ext/tempfile'

module Builder::Wat
  class Builder

    @@wat_compiler = 'wat2wasm'

    attr_reader :target, :source

    def initialize(source, target, include_paths = nil)
      check_compiler
      @source = source
      @target = target
      @include_paths = include_paths || ['.', File.expand_path('../../machine', source)]
      if File.extname(source) == '.erb'
        @wat_path = self.assemble
      else
        @wat_path = source
      end
    end

    def check_compiler
      raise "wat2wasm compiler not found. Make sure it is in your PATH" \
        unless system("#{@@wat_compiler} --help >/dev/null")
    end

    def compile
      @target ||= @wat_path.gsub(/\.wat$/,'.wasm')
      %x{ #{@@wat_compiler} #{@wat_path} -o #{@target} }
      @target
    end

    def cleanup
      File.unlink(@wat_path) unless @wat_path == @source
    end

    # Create a tempfile with .wat extension from 
    # an erb template
    def assemble
      renderer = Renderer.new(@include_paths)
      tf = Tempfile.new([File.basename(@source), '.wat'])
      tf.persist! # do not delete tempfile if inspection needed
      tf.write(renderer.render(@source))
      tf.close
      tf.path
    end
  end
end
