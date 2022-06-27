# Rlang language, compiler and libraries
# Copyright (c) 2019-2022, Laurent Julliard and contributors
# All rights reserved.

# Rlang classes
require_relative '../../utils/log'
require_relative './wtype'
require_relative './const'
require_relative './module'

module Rlang::Parser
  # Note: Cannot use Class as class name
  # because it's already used by Ruby
  class Klass < Module
    include Log

    attr_accessor   :super_class

    def initialize(const, scope_class, super_class)
      super(const, scope_class)
      self.super_class = super_class
    end

  end
end