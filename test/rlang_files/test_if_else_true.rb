class Test
  export
  def self.test_if_else_true
    local1 = 10
    if local1 >= 11
      local1 = 20
    else
      local1 = 100
    end
    return local1
  end
end