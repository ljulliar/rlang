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

  # There are 3 ways to initialize a new String object
  #  * with a string literal (e.g. mystring = "Hello World!")
  #  * by pointing at an existing memory location (e.g. String.new(ptr, length))
  #  * by asking Rlang to allocate the String space when ptr is NULL (e.g. String.new(0, length))
  def initialize(ptr, length)
    result :none
    if ptr == 0
      @ptr = Malloc.malloc(length)
    else
      @ptr = ptr
    end
    @length = length
  end


  def size; @length; end
  def to_s; self; end

  def +(stg)
    arg stg: :String
    result :String
    new_length = self.length + stg.length
    # allocate space for concatenated string
    new_ptr = Malloc.malloc(new_length)
    Memory.copy(self.ptr, new_ptr, self.length)
    Memory.copy(stg.ptr, new_ptr + self.length, stg.length)
    # Create new object string
    String.new(new_ptr, new_length)
  end

  # Only positive indices are supported for now
  def [](idx)
    result :String
    # The condition below should actually return nil
    # to be compliant with the Ruby library but we don't
    # have nil in Rlang
    #if (idx >= self.length) || (idx < -self.length)
    #  return String.new(0,0)
    #end
    #idx = (self.length + idx) if idx < 0
    if (idx >= self.length) 
      return String.new(0,0)
    end
    stg = String.new(0,1)
    Memory.copy(self.ptr+idx, stg.ptr, 1)
    stg
  end

  def reverse!
    result :String
    size = self.size
    half_size = size/2
    i=0
    while i < half_size
      swap = Memory.load32_8(self.ptr+i)
      Memory.store32_8(self.ptr+i, Memory.load32_8(self.ptr+size-1-i))
      Memory.store32_8(self.ptr+size-1-i, swap)
      i += 1
    end
    self
  end


end
