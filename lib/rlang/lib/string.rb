require_relative './malloc'

class String
  attr_reader :length, :ptr

  # str is a pointer to a memory 
  # location of type :String allocated either
  # statically through a string litteral or
  # through a dynamic allocation
  # ptr is a simple memory address of type
  # :I32 (see it as the equivalent of a
  # char * in C)
  def initialize(ptr, length)
    @ptr = ptr
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

end
