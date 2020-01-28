class Test
  # Should drop the return value
  export
  def self.test_def_no_result_returned
    result :none
    1+2
    b = 3*4
  end
end