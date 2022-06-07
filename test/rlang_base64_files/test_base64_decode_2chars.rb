require 'rlang_core'
require 'base64'

class Test
  export
  def self.test_base64_decode_2chars
    result :String
    Base64.decode64("QUI=\n")
  end
end