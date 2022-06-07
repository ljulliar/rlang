require 'rlang_core'
require 'base64'

class Test
  export
  def self.test_base64_decode_1char
    result :String
    Base64.decode64("QQ==\n")
  end
end