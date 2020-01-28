class Test
  export
  def self.test_loop_break
    local3 = 0
    while local3 < 12
      break if local3 >= 5
      local3 += 1
    end
    return local3
  end
end