class Tree
  def instance_m1; 3; end
  def instance_m2(arg1); arg1; end
  def instance_m3(arg1, arg2); arg1 + arg2; end
end

MYCONST = Tree.new

class Test
  export
  def self.test_call_instance_method_on_const(arg1)
    x = 1000000
    x = x + MYCONST.instance_m1 # 1000003
    x = x + MYCONST.instance_m2(5) * 100 # 1000503
    x = x + MYCONST.instance_m3(5,2) * 10000 # 1070503
  end
end