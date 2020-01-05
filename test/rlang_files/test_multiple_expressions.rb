class Test
  export
  def self.test_multiple_expressions
    local1 = (arg1 = 10; arg1 = 12) + 20
  end
end