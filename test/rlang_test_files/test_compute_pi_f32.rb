class Test

  export
  def self.test_compute_pi_f32
    result :F32
    local n: :F32, pi: :F32
    n = 3
    s = -1
    pi = 1.0
    while n < 10000000
      if s == 1
        pi = pi + 1.0/n
        s = -1
      else
        pi = pi - 1.0/n
        s = 1
      end
      n += 2.0
    end
    return 4 * pi
  end

end