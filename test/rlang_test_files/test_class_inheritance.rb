class TestA
  def ma; 1; end
  def self.ma; 2; end
end

class TestB < TestA
  def mb; 10; end
  def self.mb; 20; end
end

class Test
  export
  def self.test_class_inheritance
    TestA.ma + TestA.new.ma + \
    TestB.ma + TestB.new.ma + TestB.mb + TestB.new.mb
  end
end
