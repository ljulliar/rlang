class Test
  export
  def self.test_if_else_false
    local1 = 18
    if local1 <= 20
      local1 = 20
    else
      local1 = 10
    end
    return local1
  end
end