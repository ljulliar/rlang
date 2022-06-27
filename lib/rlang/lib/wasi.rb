# Rlang language, compiler and libraries
# Copyright (c) 2019-2022, Laurent Julliard and contributors
# All rights reserved.
#
# WASI Interface to WASM runtime

require_relative './array'
require_relative './string'

ARGC = 0
ARGV = 0.cast_to(:Array32)
ENV  = 0.cast_to(:Array32)

class WASI
  STDIN_FD  = 0
  STDOUT_FD = 1
  STDERR_FD = 2
  @@argv_buf_size = 0
  @@environc = 0
  @@environ_buf_size = 0

  class CIOVec
    attr_reader :ciovs
    attr_type ciovs: :Array32

    def initialize(n)
      result :none
      # a ciov is list of n (address to buffer, length of buffer)
      @n = n
      @index = 0
      @max_index = 2 * @n
      @ciovs = Array32.new(2*n)
    end

    def << (string)
      arg string: :String
      result :CIOVec
      raise "CIOVec full !" if @index >= @max_index
      @ciovs[@index] = string.ptr
      @ciovs[@index+1] = string.length
      @index += 2
      self
    end

    def free
      result :none
      @ciovs.free
      Object.free(self)
    end
  end

  # An IOVec is an array of (address to buffer, length of buffer)
  # where WASM runtime can read data coming from the WASM module
  class IOVec
    attr_reader :iovs
    attr_type iovs: :Array32

    IOV_SIZE = 1024

    def initialize(n)
      result :none
      @iovs = Array32.new(2*n)
      @n = n
      i = 0
      while i < n;
        @iovs[i] = Malloc.malloc(IOV_SIZE)
        @iovs[i+1] = IOV_SIZE
        i += 2
      end
    end

    def free
      result :none
      i = 0
      while i < @n
        Malloc.free(@iovs[i])
        i += 2
      end
      @iovs.free
      Object.free(self)
    end
  end

  # Import WASI functions
  import :wasi_unstable, :args_sizes_get
  def self.args_sizes_get(argc, args_size); end

  import :wasi_unstable, :args_get
  def self.args_get(argv, argv_buf); end
  
  import :wasi_unstable, :environ_get
  def self.environ_get(environ, environ_buf); end

  import :wasi_unstable, :environ_sizes_get
  def self.environ_sizes_get(environc, environ_buf_size); end

  import :wasi_unstable, :fd_write
  def self.fd_write(fd, iovs, iovs_count, nwritten_ptr); end

  import :wasi_unstable, :fd_read
  def self.fd_read(fd, iovs, iovs_count, nread_ptr); end

  import :wasi_unstable, :proc_exit
  def self.proc_exit(exitcode); result :none; end

  def self.argv_init
    local argv: :Array32, environ: :Array32

    # Get number of arguments and their total size
    errno = WASI.args_sizes_get(ARGC.addr, @@argv_buf_size.addr)
    raise "Errno args_sizes_get" if errno != 0

    # Allocate memory areas to receive the argument pointers
    # (argv) and the argument strings (argv_buf)
    #
    # Setup an extra slot in argv array to simplify the
    # loop below
    argv = Array32.new(ARGC+1) # Assuming I32 for pointers
    argv_buf = Malloc.malloc(@@argv_buf_size)
    errno = WASI.args_get(argv.ptr, argv_buf)

    raise "Errno args_get" if errno != 0
    argv[ARGC] = argv[0] + @@argv_buf_size

    # Workaround to avoid dynamic constant assignment error
    Memory.store32(ARGV.addr, Array32.new(ARGC))

    # Now scan through arguments and turn them into a Rlang
    # Array of Strings (like ARGV in Ruby)
    i = 0
    while i < ARGC
      length = argv[i+1] - argv[i] - 1 # -1 because of null terminated
      ARGV[i] = String.new(argv[i], length)
      # Nullify argv[i] so that String is not freed
      argv[i] = 0
      i += 1
    end
    argv.free
    return errno
  end

  # Initialize WASI environment and related Rlang
  # objects (ARGC, ARGV,...)
  def self.environ_init
    local environ: :Array32

    # Get environ variable count and buf size
    errno = WASI.environ_sizes_get(@@environc.addr, @@environ_buf_size.addr)
    raise "Errno environ_sizes_get" if errno != 0

    # Allocate memory areas to receive the env var pointers
    # (env) and the env var strings (env_buf)
    environ = Array32.new(@@environc+1) # Assuming I32 for pointers
    environ_buf = Malloc.malloc(@@environ_buf_size)
    errno = WASI.environ_get(environ.ptr, environ_buf)

    raise "Errno environ_get" if errno != 0
    environ[@@environc] = environ[0] + @@environ_buf_size

    # Workaround to avoid dynamic constant assignment error
    Memory.store32(ENV.addr, Array32.new(@@environc))

    # Now scan through arguments and turn them into a Rlang
    # Array of Strings (like ARGV in Ruby)
    i = 0
    while i < @@environc
      length = environ[i+1] - environ[i] - 1 # -1 because of null terminated
      ENV[i] = String.new(environ[i], length)
      # Nullify environ[i] so that String is not freed
      #environ[i] = 0
      i += 1
    end
    #environ.free

    return errno
  end

  def self.init
    self.argv_init
    self.environ_init
  end

end

