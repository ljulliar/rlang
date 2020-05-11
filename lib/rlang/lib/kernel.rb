# Rubinius WebAssembly VM
# Copyright (c) 2019-2020, Laurent Julliard and contributors
# All rights reserved.
#
# Kernel methods
#
# Most of the Kernel methods are defined in other files
# to avoid requiring classes that rely on Kernel methods
# themselves.

class String; end

module Kernel

  def raise(msg)
    arg msg: :String
    result :none
    #$! = msg
    #STDERR.puts msg
    inline wat: '(unreachable)', wtype: :none
  end

end