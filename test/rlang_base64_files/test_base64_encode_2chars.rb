require 'rlang_core'
require 'base64'

class Test
  export
  def self.test_base64_encode_2chars
    result :String
    Base64.encode64("AB")
  end
end