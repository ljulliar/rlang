require_relative '../../utils/log'
require_relative './memory'
require_relative '../../rlang/parser/ext/string'
require_relative '../../rlang/parser/ext/type'
require_relative '../../rlang/parser/ext/integer'


# Don't use class name Data because it's a deprecated
# Ruby class and it generates warning at runtime
class DAta

  @@symbol_table = {}
  @@current_address = 0

  attr_reader :symbol, :value, :wtype, :address

  def initialize(symbol, value, wtype=Type::I32)
    @symbol = symbol
    @value = (value.is_a?(Array) ? value : [value])
    @wtype = wtype
    @address = @@current_address
    @@symbol_table[@symbol] = self
    size = self.update(@symbol, @value, @wtype)
    Log.debug "size after update #{size}"
    @@current_address += size
  end

  def update(symbol, value, wtype)
    Log.debug "updating data value #{value} at #{address} / #{wtype.size}"
    original_address = self.address
    new_address = address
    value.each do |elt|
      if elt.is_a? String
        elt.each_byte do |b| 
          Memory.store(new_address, b, 8)
          new_address += 1
        end
      elsif elt.is_a? Integer
        Memory.store(new_address, elt, wtype.size*8)
        new_address += wtype.size
        Log.debug "new _address : #{new_address}"
      else
        raise "Unknown Data type: #{value.class}"
      end
    end
    new_address - original_address
  end

  def self.has_symbol?(symbol)
    @@symbol_table.has_key? symbol
  end

  def self.[](symbol)
    raise "Unknown data symbol '#{symbol}'" unless self.has_symbol? symbol
    @@symbol_table[symbol].address
  end

  # Store string or integer in memory
  # (note: integer are treated as I32)
  def self.[]=(symbol, value)
    if self.has_symbol? symbol
      self.update(symbol, value)
    else
      self.new(symbol, value)
    end
  end

  def self.address=(address)
    @@current_address = address
  end

  # Align current address to closest multiple of
  # n by higher value
  def self.align(n)
    if (m = @@current_address % n) != 0
      @@current_address = (@@current_address - m) + n
    end
  end

end