require 'rlang_core'

class Square
  attr_accessor :side
  attr_type side: :I64

  def area
    result :I64
    self.side * self.side
  end
end

class Test
  # Statically allocate a Circle object
  @@square = Square.new

  export
  def self.test_attr_definition_with_type(s)
    arg s: :I64
    result :I64
    @@square.side = s
    @@square.area
  end
end