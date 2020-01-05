class Test
  export
  def self.test_if_modifier(arg1)
    arg1 = arg1 * 2 if arg1 > 5
    return arg1
  end
end