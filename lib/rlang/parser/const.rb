# Rubinius WebAssembly VM
# Copyright (c) 2019, Laurent Julliard and contributors
# All rights reserved.

# Constant variables

require_relative './ext/type'
require_relative './cvar'

# Constants and Class variables are managed
# in exactly the same way
module Rlang::Parser
  class Const < CVar
  end
end
