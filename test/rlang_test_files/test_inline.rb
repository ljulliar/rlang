class Test
  export
  def self.test_inline(arg1)
    arg1 *= 10
    inline wat: '(i32.mul 
                   (local.get $arg1) (local.get $arg1))',
           ruby: 'arg1 ** 2'
  end
end
