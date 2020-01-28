class Cube
  wattr :x, :y, :z, :color
  wattr_type x: :I64, y: :I64, z: :I64, color: :I32

  def volume
    result :I64
    self.x * self.y * self.z
  end
end
