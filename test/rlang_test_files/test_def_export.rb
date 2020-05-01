class Test
  export :my_function_name
  def self.test_def_export_with_name
    10
  end

  export
  def self.test_def_export
    100
  end
end