require 'rlang/lib'

class Test
  export
  def self.test_string_concat
    result :String
    stg1 = "A first string."
    stg2 = " And a second one"
    stg1 + stg2
  end
end