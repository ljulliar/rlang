require_relative './malloc'

class Object
  # don't use allocate as a name to avoid
  # colliding with Ruby native method in 
  # Rlang simulator
  def self.alloc(nbytes)
    result :I32
    Malloc.malloc(nbytes)
  end

  def self.free(object_ptr)
    result :none
    Malloc.free(object_ptr)
  end
end