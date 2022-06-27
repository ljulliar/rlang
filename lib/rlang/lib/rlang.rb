# Rlang language, compiler and libraries
# Copyright (c) 2019-2022, Laurent Julliard and contributors
# All rights reserved.
#
# Rlang standard library classes and modules
# and runtime initialization
#
require_relative './rlang_core'
require_relative './wasi'
require_relative './io'

class Rlang
  def self.init
    # WASI init: setup ARGC, ARGV, etc...
    errno = WASI.init

    # IO init: setup fd of stdin, out and err
    # This code cannot be executed within io.rb
    # as STDxxx can only be used after io.rb is
    # compiled
    STDIN.fd  = WASI::STDIN_FD
    STDOUT.fd = WASI::STDOUT_FD
    STDERR.fd = WASI::STDERR_FD
    $stdin  = STDIN
    $stdout = STDOUT
    $stderr = STDERR
    errno
  end
end