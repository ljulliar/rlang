# Rubinius WebAssembly VM
# Copyright (c) 2019, Laurent Julliard and contributors
# All rights reserved.

require_relative '../ext/tempfile'

module Builder::Wat
  class Builder

    @@wat_compiler = 'wat2wasm'

    attr_reader :target, :source

    # Source file must be an ERB template
    def initialize(source, include_paths = nil)
      @source = source
      @include_paths = include_paths || ['.', File.expand_path('../../machine', source)]
      @wat_path = self.assemble
    end

    def compile
      @target = @wat_path.gsub(/\.wat$/,'.wasm')
      %x{ #{@@wat_compiler} #{@wat_path} -o #{@target} }
      @target
    end

    def cleanup
      File.unlink(@wat_path)
      File.unlink(@wasm_path)
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
