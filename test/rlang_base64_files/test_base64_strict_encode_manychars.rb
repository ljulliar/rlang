require 'rlang_core'
require 'base64'

class Test
  export
  def self.test_base64_strict_encode_manychars
    result :String
    Base64.strict_encode64("\0\1\2\3"*34)
  end
end