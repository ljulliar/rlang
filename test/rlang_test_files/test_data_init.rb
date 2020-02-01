DAta.address = 0
DAta[:a_string] = "My\tLittle\tRlang\x00"
DAta.align(4)
DAta[:an_I64] = 32_000_000_000.to_I64
DAta[:an_I32] = 32_000
DAta[:an_address] = DAta[:a_string]
DAta[:an_array] = [DAta[:an_I64], 5, 257, "A string\n"]
DAta.align(8) # realign for future data

# Wasmer runtime expects some function
# (not sure why)
class Test
  export
  def self.test_data_init
    result :none
  end
end