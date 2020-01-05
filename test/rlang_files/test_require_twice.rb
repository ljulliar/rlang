require 'test_def_two_args'
require 'test_def_two_args'

class Test
  export
  def self.test_require_twice
    self.test_def_two_args(10,100)
  end
end