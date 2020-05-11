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

  def size; @length; end
  def to_s; self; end

end
