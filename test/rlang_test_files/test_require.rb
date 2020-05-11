require_relative './test_def_two_args'

class Test
  export
  def self.test_require
    self.test_def_two_args(10,100)
  end
end