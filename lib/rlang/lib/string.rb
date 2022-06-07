require_relative './malloc'
require_relative './memory'

class String
  attr_reader :length, :ptr

  # str is a pointer to a memory 
  # location of type :String allocated either
  # statically through a string litteral or
  # through a dynamic allocation
  # ptr is a simple memory address of type
  # :I32 (see it as the equivalent of a
  # char * in C)
  #
  # There are 3 ways to initialize a new String object
  #  * with a string literal (e.g. mystring = "Hello World!")
  #  * by pointing at an existing memory location (e.g. String.new(ptr, length))
  #  * by asking Rlang to allocate the String space when ptr is NULL (e.g. String.new(0, length))
  # No memory is allocated for the string bytes if the string is empty
  def initialize(ptr, length)
    result :none
    if ptr == 0
      if length == 0
        @ptr = 0
      else
        @ptr = Malloc.malloc(length)
      end
    else
      @ptr = ptr
    end
    @length = length
  end

  def size; @length; end
  def to_s; self; end

  def empty?
    @length == 0
  end

  def ord
    result :I32
    Memory.load32_8(@ptr)
  end

  def +(stg)
    arg stg: :String
    result :String

    # Create new object string with proper size
    s = String.new(0, @length + stg.length)
    # Copy both strings in the new one
    Memory.copy(@ptr, s.ptr, @length)
    Memory.copy(stg.ptr, s.ptr + @length, stg.length)
    s
  end

  # Only positive indices are supported for now
  def [](idx)
    result :String
    # The condition below should actually return nil
    # to be compliant with the Ruby library but we don't
    # have nil in Rlang
    #if (idx >= @length) || (idx < -@length)
    #  return String.new(0,0)
    #end
    #idx = (@length + idx) if idx < 0
    if (idx >= @length) 
      return String.new(0,0)
    end
    stg = String.new(0,1)
    Memory.copy(@ptr+idx, stg.ptr, 1)
    stg
  end

  # Only positive indices are supported for now
  def []=(idx, stg)
    arg stg: :String
    result :String
    if (idx >= @length)
      raise "IndexError: index out bound"
    else
      i=0
      tgt_ptr = @ptr+idx
      while i < stg.length && (idx + i) < @length
        Memory.copy(stg.ptr+i, tgt_ptr+i, 1)
        i += 1
      end
    end
    stg
  end

  def *(times)
    result :String
    full_length = @length * times
    stg = String.new(0, full_length)
    idx=0
    while idx < full_length
      stg[idx] = self
      idx += @length
    end
    stg
  end

  def reverse!
    result :String
    half_size = @length/2
    i=0
    while i < half_size
      swap = Memory.load32_8(@ptr+i)
      Memory.store32_8(@ptr+i, Memory.load32_8(@ptr+@length-1-i))
      Memory.store32_8(@ptr+@length-1-i, swap)
      i += 1
    end
    self
  end

  def ==(stg)
    arg stg: :String
    return false if stg.length != @length
    i = 0
    stg_ptr = stg.ptr
    while i < @length
      return false if Memory.load32_8(@ptr+i) != Memory.load32_8(stg_ptr+i)
      i += 1
    end
    true
  end
  
  def !=(stg)
    arg stg: :String
    !(self == stg)
  end

end
