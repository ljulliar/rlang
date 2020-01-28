require_relative './cube'

class Test

  @@cvar = Cube.new

  export
  def self.test_object_pointer_add
    local c1: :Cube

    c1 = @@cvar + 2
    # should return size of cube 
    c1.to_I32 - @@cvar.to_I32
  end
end