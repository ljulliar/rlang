require 'test_sample'

class Test
  export
  def self.test_require_wat
    inline wat: '(call $wat_sample (i32.const 1))'
  end
end