class Test
  export
  def self.test_loop_unless_modifier(arg1)
    arg1 = arg1 * 2 unless arg1 > 5
    return arg1
  end
end