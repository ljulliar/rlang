class TestA
  CA = 1
end

class TestB < TestA
  CB = 10
  def self.mb; CA; end
end

class TestC < TestB
  CC = 100
  def self.mc; CB; end
end


class Test
  export
  def self.test_constant_in_inherited_classes
    TestA::CA + \
    TestB::CB + TestB::mb + \
    TestC::CC + TestC::mc
  end
end
