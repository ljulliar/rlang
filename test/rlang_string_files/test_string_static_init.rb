require 'rlang/lib'

MYSTRING1 = "A first string"
MYSTRING2 = "A second waaaaaaaaaayyyyyyyy longer string"

class Test
  export
  def self.test_string_static_init
    MYSTRING1.length * 1000 + MYSTRING2.length
  end
end