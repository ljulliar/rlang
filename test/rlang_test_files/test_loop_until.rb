class Test
  export
  def self.test_loop_until
    local2 = 6
    until local2 == 10
      local2 += 1
    end
    return local2
  end
end