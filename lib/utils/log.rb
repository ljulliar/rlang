# Rubinius WebAssembly VM
# Copyright (c) 2019, Laurent Julliard and contributors
# All rights reserved.
#
# Rlang logging module

require 'logger'

module Log
  class << self
    def logger
      @logger ||= Logger.new($stdout)
    end

    def logger=(logger)
      @logger = logger
    end
  end

  # Addition
  def self.included(base)
    class << base
      def logger
        Log.logger
      end
    end
  end

  def logger
    Log.logger
  end
end
