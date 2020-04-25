module M
  def m1; 1; end
  def m2; 4; end
  def m3; 5; end
end

class A
  include M
  def m1; 2; end
  def m4; 7; end
end

class B
  prepend M
  def m1; 3; end
  def m5; 6; end
end

class C < B
  def m2; 7; end
end

class D < A
  include M
  def m2; 6;end
end

class Test
  export
  def self.test_call_method_lookup_with_modules
    a = A.new
    b = B.new
    # Total should equal to 64142
    a.m1 + 10*a.m2 +  # 42
    100*b.m1 + 1_000*b.m2 + 10_000*b.m5  # 64 100
  end

  export
  def self.test_call_method_lookup_with_superclasses
    c = C.new
    d = D.new
    # Total should equal to 756271
    c.m1 + 10*c.m2 +  # 71
    + 100*d.m1 + 1_000*d.m2 + 10_000*d.m4  # 76100
  end
end