# Rlang language, compiler and libraries
# Copyright (c) 2019-2022, Laurent Julliard and contributors
# All rights reserved.
#
# IO class for all basic input and output operations

require_relative './wasi'

class IO
  attr_accessor :fd

  @@num_bytes_written = 0
  @@num_bytes_read    = 0

  def initialize(fd)
    @fd = fd
  end

  def write(stg)
    arg stg: :String
    ciovec = WASI::CIOVec.new(1)
    ciovec << stg
    errno = WASI.fd_write(@fd, ciovec.ciovs.ptr, 1, @@num_bytes_written.addr)
    ciovec.free
    errno
  end

  def print(stg)
    self.write(stg)
  end

  def puts(stg)
    arg stg: :String
    result :none
    ciovec = WASI::CIOVec.new(2)
    ciovec << stg
    ciovec << "\n"
    errno = WASI.fd_write(@fd, ciovec.ciovs.ptr, 2, @@num_bytes_written.addr)
    ciovec.free
  end   

  def read
    result :String
    local stg: :String
    iovec = WASI::IOVec.new(1)
    errno = WASI.fd_read(@fd, iovec.iovs.ptr, 1, @@num_bytes_read.addr)
    # -1 below because of \0 terminated string
    stg = String.new(iovec.iovs[0], @@num_bytes_read-1) 
    # Nullify the iovs entry used by the String object so it is not freed
    iovec.iovs[0] = 0
    iovec.free
    stg
  end

end

STDIN  = IO.new
STDOUT = IO.new
STDERR = IO.new

module Kernel

  def puts(stg)
    arg stg: :String
    result :none
    STDOUT.puts(stg)
  end

  def print(stg)
    arg stg: :String
    result :none
    STDOUT.print(stg)
  end

end
