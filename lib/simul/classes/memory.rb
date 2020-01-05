require_relative './../rlang/parser/ext/type.rb'

class Memory

  # Initial memory size (8 pages of WASM memory - 64 KB each)
  MAX_SIZE = 8
  WASM_PAGE_SIZE = 64 * 1024
  MAX_I32 = 2**32 - 1
  @@mem = nil

  # size unit in WASM pages (64 KB)
  def self.init(max_size)
    @@max_size = max_size || MAX_SIZE
    @@mem_size = @@max_size * WASM_PAGE_SIZE
    @@mem = String.new("\00"*@@mem_size, encoding:'ASCII-8BIT', capacity: @@mem_size)
  end

  def self.size
    @@max_size
  end

  def self.size_in_bytes
    @@mem_size
  end

  def self.dump
    @@mem
  end

  def self.load(address, type=Type::I32 , nbits=nil, signed=false)
    if type == Type::I32
      if nbits.nil? || nbits == 32
        # i32.load: load 4 bytes as i32
        value = @@mem.byteslice(address,4).unpack('L').first
      elsif nbits == 16
        if signed
          # i32.load16_s: load 2 bytes and sign-extend i16 to i32
          value = @@mem.byteslice(address,2).unpack('s').first
        else
          # i32.load16_u: load 2 bytes and zero-extend i16 to i32
          value = @@mem.byteslice(address,2).unpack('S').first
        end
      elsif nbits == 8
        if signed
          # i32.load8_s: load 1 byte and sign-extend i8 to i32
          value = @@mem.byteslice(address).unpack('c').first
        else
          # i32.load16_u: load 1 byte and zero-extend i8 to i32
          value = @@mem.byteslice(address).unpack('C').first
        end
      else
        raise "Unknown number of bits #{nbits}"
      end
      return Type::I32.new(value)
    elsif type == Type::I64
      if nbits.nil? || nbits == 64
        # i64.load: load 8 bytes as i64
        value = @@mem.byteslice(address,8).unpack('Q').first
      elsif nbits == 32
        if signed
          # i64.load32_s: load 4 bytes and sign-extend i32 to i64
          value = @@mem.byteslice(address,4).unpack('l').first
        else
          # i64.load32_u: load 4 bytes and zero-extend i32 to i64
          value = @@mem.byteslice(address,4).unpack('L').first
        end
      elsif nbits == 16
        if signed
          # i64.load16_s: load 2 bytes and sign-extend i16 to i64
          value = @@mem.byteslice(address,2).unpack('s').first
        else
          # i64.load16_u: load 2 bytes and zero-extend i16 to i64
          value = @@mem.byteslice(address,2).unpack('S').first
        end
      elsif nbits == 8
        if signed
          # i64.load8_s: load 1 byte and sign-extend i8 to i64
          value = @@mem.byteslice(address).unpack('c').first
        else
          # i64.load8_u: load 1 byte and zero-extend i8 to i64
          value = @@mem.byteslice(address).unpack('C').first
        end
      else
        raise "Unknown number of bits #{nbits}"
      end
      return Type::I64.new(value)
    else
      raise "Unknown target type #{type}"
    end

  end

  def self.store(address, value, nbits=32)
    #puts '***', address, value, nbits
    if value.is_a? Integer || (value.is_a? Type::I32)
      raise "Value #{value} too large to fit in 32 bits at address #{}" if value > MAX_I32
      case nbits
      when 64
        raise "Cannot store i64 in i32 memory location (wrap/truncate first)"
      when nil, 32
        # i32.store: (no conversion) store 4 bytes
        @@mem[address,4] = [value].pack('L<')
      when 16
        # i32.store16: wrap i32 to i16 and store 2 bytes
        @@mem[address,2] = [value].pack('S<')
      when 8
        # i32.store8: wrap i32 to i8 and store 1 byte
        @@mem[address] = [value].pack('C')
      end
    elsif value.is_a? Type::I64
      case nbits
      when nil, 64
        # i64.store: (no conversion) store 8 bytes
        @@mem[address,8] = [value].pack('Q<')        
      when 32
        # i64.store32: (no conversion) store 4 bytes
        @@mem[address,4] = [value].pack('L<')
      when 16
        # i64.store16: wrap i32 to i16 and store 2 bytes
        @@mem[address,2] = [value].pack('S<')
      when 8
        # i64.store8: wrap i32 to i8 and store 1 byte
        @@mem[address] = [value].pack('C')
      end
    else
      raise "Unknow data type #{value.class} for #{value}"
    end

  end

end