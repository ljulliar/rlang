MYCONST1 = 3

class Test
  MYCONST2 = 5
  export
  def self.test_constant_init
    (MYCONST1 * 100 + MYCONST2) * 100
  end
end