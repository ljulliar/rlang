class Test
  export
  def self.test_opasgn_embedded(arg1)
    local1 = (arg1 += 2) + 20
  end
end