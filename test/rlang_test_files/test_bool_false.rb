class Test
  export
  def self.test_bool_false
    x = 0
    if !false
      x += 1 # 1
    end

    if false
      x += 10 
    end

    while !false
      x += 100 # 101
      break
    end

    while false
      x += 1000
    end

    until false
      x += 10000 # 10101
      break
    end

    until !false
      x += 100000
    end
    x
  end
end