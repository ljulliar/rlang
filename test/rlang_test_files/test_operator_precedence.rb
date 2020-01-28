class Test
  export
  def self.test_operator_precedence
    x = (1 + 5 - 2) # 4
    y = 1 + 6 / 3   # 3
    z = (1 + 10 - 9) * 3 + 1 # 7
    x + 100*y + 10000*z # 70304
  end
end