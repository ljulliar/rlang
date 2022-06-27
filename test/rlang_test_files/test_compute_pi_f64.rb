class Test

  export
  def self.test_compute_pi_f64
    result :F64
    local n: :F64, pi: :F64
    n = 3
    s = -1
    pi = 1.0
    while n < 1000000000
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