class Test
  export
  def self.test_if_else_false_with_type_i64
    local :local1, :I64
    result :I64
    local1 = 18
    if local1 <= 20
      local1 = 20
    else
      local1 = 10
    end
    return local1
  end
end