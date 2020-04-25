class TestA
  CA = 1
  class TestB
    CB = 10
    def self.mb; CA; end
    class TestC
      CC = 100
      def self.mc; CB; end
    end
  end
end

class Test
  #export
  def self.test_constant_in_embedded_classes
    TestA::CA + \
    TestA::TestB::CB + TestA::TestB.mb + \
    TestA::TestB::TestC::CC + TestA::TestB::TestC.mc
  end
end
