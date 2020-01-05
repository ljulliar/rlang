class Test
  export
  def self.test_if_true
    local1 = 10
    if local1 > 8
      local1 += 20
    end
    return local1
  end
end