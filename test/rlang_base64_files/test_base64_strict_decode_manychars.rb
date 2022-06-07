require 'rlang_core'
require 'base64'

class Test
  export
  def self.test_base64_strict_decode_manychars
    result :String
    # Encoded version of "\t\r\0\0"*20
    Base64.strict_decode64("CQ0AAAkNAAAJDQAACQ0AAAkNAAAJDQAACQ0AAAkNAAAJDQAACQ0AAAkNAAAJDQAACQ0AAAkNAAAJDQAACQ0AAAkNAAAJDQAACQ0AAAkNAAA=")
  end
end