# Rubinius WebAssembly VM
# Copyright (c) 2019-2020, Laurent Julliard and contributors
# All rights reserved.
#
# Kernel methods

$! = 0.cast_to(:String)

module Kernel

  def raise(msg)
    arg msg: :String
    result :none
    $! = msg
    inline wat: '(unreachable)', wtype: :none
  end

end