# Rubinius WebAssembly VM
# Copyright (c) 2019, Laurent Julliard and contributors
# All rights reserved.
#
# Turns an Rlang source file into a Wasm file
# either by executing the rlang command or by
# running the parser/compiler from within this
# class

require_relative '../ext/tempfile'
require_relative '../wat'
require_relative './compiler'

module Builder::Rlang
  class Builder

    LIB_DIR = File.expand_path('../../../../lib', __FILE__)
    RLANG = File.expand_path('../../../../bin/rlang', __FILE__)

    attr_reader :source, :target, :wat_path
    attr_accessor :use_rlang_command

    # source: Path to Rlang file (.rb)
    # target: Path to Wasm file (.wasm)
    # options: Rlang parser options (parser.config)
    #
    # options is either a string when using rlang compiler
    # or a hash of parser options when using the parser
    def initialize(source, target, options=nil)
      @source = source
      @target = target
      @options = options
      @use_rlang_command = false
    end

    def use_rlang_command!
      @use_rlang_command = true
    end

    # return true if everything went well, false otherwise
    def compile
      if @use_rlang_command
        system("ruby -I#{LIB_DIR} -- #{RLANG} #{@options || ''} --wasm -o #{target} #{@source}")
      else
        # Compile the Rlang file into a WAT file
        @compiler = Compiler.new(@source, nil, @options)
        if @compiler.compile
          tf_path = @compiler.target
        else
          return false
        end
        # turn the WAT file into Web Assembly code
        wat_builder = ::Builder::Wat::Builder.new(tf_path, @target)
        @target ||= wat_builder.target
        return wat_builder.compile
      end
    end

    def cleanup
      @compiler.cleanup
    end
  end
end
