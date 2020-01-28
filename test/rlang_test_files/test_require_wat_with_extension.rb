require 'test_sample.wat'

class Test
  export
  def self.test_require_wat_with_extension
    inline wat: '(call $wat_sample (i32.const 1))'
  end
end