# Rubinius WebAssembly VM
# Copyright (c) 2019, Laurent Julliard and contributors
# All rights reserved.

require 'pathname'
require 'erb'

module Builder
  module Wat
    class Renderer 
      attr_reader :template_path, :binding_klass

      def initialize(template_paths)
        # an array of load path to consider for erb files
        @template_paths = template_paths
      end

      def render(erb_file)
        path = ''
        unless Pathname.new(erb_file).absolute?
          path = @template_paths.find { |tp| File.exist?(File.join(tp, erb_file)) } || ''
        end
        #puts "Rendering #{File.join(path, erb_file)}"
        ERB.new(File.read(File.join(path, erb_file))).result(binding)
      end
    end
  end
end