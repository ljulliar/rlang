# Rubinius WebAssembly VM
# Copyright (c) 2019, Laurent Julliard and contributors
# All rights reserved.
#
# Rlang exceptions

class RlangSyntaxError < StandardError; end

def rlse(node, msg)
  msg += "\nline #{node.location.line}: #{node.location.expression.source}"
  raise  RlangSyntaxError, msg, []
end