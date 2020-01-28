class TestA
  CONST = 1000
end

class Test
  export
  def self.test_constant_in_other_class
    1 + TestA::CONST
  end
end