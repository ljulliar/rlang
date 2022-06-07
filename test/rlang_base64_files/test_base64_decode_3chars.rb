require 'rlang_core'
require 'base64'

class Test
  export
  def self.test_base64_decode_3chars
    result :String
    Base64.decode64("QUJD\n")
  end
end