module M
  def add(a,b)
    a + b
  end

  def other(a,b)
    a * b
  end
end

class Test
  include M

  # This method has priority over M#add
  def other(a,b)
    1000 + a + b
  end

  export
  def self.test_module_include
    Test.new.add(3,10) + Test.new.other(5, 20)
  end
end