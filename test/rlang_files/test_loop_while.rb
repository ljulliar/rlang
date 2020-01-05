class Test
  export
  def self.test_loop_while
    local1 = 8
    while local1 > 0
      local1 -= 1
    end
    return local1
  end
end