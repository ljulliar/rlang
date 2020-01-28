class Test
  export
  def self.test_bool_true
    x = 0
    if true
      x += 1 # 1
    end

    if !true
      x += 10 
    end

    while true
      x += 100 # 101
      break
    end

    while !true
      x += 1000
    end

    until !true
      x += 10000 # 10101
      break
    end

    until true
      x += 100000
    end
    x
  end
end