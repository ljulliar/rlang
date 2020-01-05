class Test
  export
  def self.test_inline_with_wtype(arg1)
    arg :arg1, :I64
    result :I64
    arg1 *= 10
    inline wat: '(i64.mul 
                   (local.get $arg1)
                   (local.get $arg1))',
           wtype: :I64,
           ruby: 'arg1 ** 2'
  end
end
