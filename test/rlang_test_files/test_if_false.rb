class Test
  export
  def self.test_if_false
    local1 = 15
    if local1 < 20
      local1 = 20
    end
    return local1
  end
end