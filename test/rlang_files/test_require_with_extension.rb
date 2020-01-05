require 'test_def_two_args.rb'

class Test
  export
  def self.test_require_with_extension
    self.test_def_two_args(10,100)
  end
end