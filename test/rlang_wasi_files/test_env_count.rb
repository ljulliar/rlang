require 'rlang_core'
require 'wasi'

class Test

  export
  def self.test_env_count
    result :I32
    # Initialize WASI environment
    errno = WASI.init
    # return number of command line arguments
    return ENV.size
  end

end