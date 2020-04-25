class A

  class B
    def inst_mb
      1
    end

    def self.class_mb
      10
    end
  end

  def inst_ma
    100
  end

  def self.class_ma
    1000
  end
end

class Test

  export
  def self.test_class_in_class
    # Call both instance and class method in Class A
    # and embedded class B
    # Should return 1111
    A.class_ma + A.new.inst_ma + A::B.class_mb + A::B.new.inst_mb
  end
end