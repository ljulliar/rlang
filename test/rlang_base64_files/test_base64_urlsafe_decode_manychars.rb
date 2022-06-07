require 'rlang_core'
require 'base64'

class Test
  export
  def self.test_base64_urlsafe_decode_manychars
    result :String
    # Encoded version of "\x00\x10\x83\xFB\xEF\xBE\x00\x10\x83\xFF\xFF\xFF\x00"
    Base64.urlsafe_decode64("ABCD----ABCD____AA==")
  end
end