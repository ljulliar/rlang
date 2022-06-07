require 'rlang_core'
require 'base64'

class Test
  export
  def self.test_base64_decode_manychars
    result :String
    # Encoded version of "\t\r\0\n"*20
    Base64.decode64("CQ0ACgkNAAoJDQAKCQ0ACgkNAAoJDQAKCQ0ACgkNAAoJDQAKCQ0ACgkNAAoJ\nDQAKCQ0ACgkNAAoJDQAKCQ0ACgkNAAoJDQAKCQ0ACgkNAAo=\n")
  end
end