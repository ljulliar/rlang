class Test
  export
  def self.test_if_elsif_else(arg1)
    if arg1 <= 10
      local1 = 1
    elsif arg1 <= 100
      local1 = 2
    elsif arg1 <= 1000
      local1 = 3
    else
      local1 = 0
    end
    return local1
  end
end