require_relative './cube'

class Test

  # Allocate some amount of statif memory
  @@cvar1 = Cube.new
  @@cvar2 = Cube.new
  @@cvar3 = Cube.new

  export
  def self.test_object_pointer_substract
    local c1: :Cube

    c1 = @@cvar3 - 1
    # should return size of cube 
    @@cvar3.to_I32 - c1.to_I32
  end
end