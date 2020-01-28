require 'test_def_two_args'
require_relative './test_require'

class Test
  export
  def self.test_require_embedded
    self.test_def_two_args(10,100)
  end
end