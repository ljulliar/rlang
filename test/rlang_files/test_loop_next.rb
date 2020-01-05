class Test
  export
  def self.test_loop_next
    acc = 0
    local3 = 0
    while local3 <= 8
      local3 += 1
      next if local3 < 7
      acc = acc * 10 + local3
    end
    return acc
  end
end