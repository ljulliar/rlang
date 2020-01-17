module Type

  class I64 < Numeric
    MAX = 2**64 - 1
    def size; 8; end  # size in bytes
    def self.size; 8; end # size in bytes
    def wasm_type; 'i64'; end
    def self.wasm_type; 'i64'; end
  end

  class I32 < Numeric
    MAX = 2**64 - 1
    def initialize(v); @v = Integer(v); end
    def +(v); I32.new(v + @v); end
    def size; 4; end # size in bytes
    def self.size; 4; end # size in bytes
    def wasm_type; 'i32'; end
    def self.wasm_type; 'i32'; end
  end

  class F64 < Numeric
    MAX = 1.7976931348623158E308
    def size; 8; end # size in bytes
    def wasm_type; 'f64'; end
    def self.size; 8; end # size in bytes
    def self.wasm_type; 'f64'; end
  end

  class F32 < Numeric
    MAX = 3.4028235E38
    # size in bytes
    def size; 4; end  
    def wasm_type; 'f32'; end
    def self.size; 4; end  
    def self.wasm_type; 'f32'; end
  end

  class Numeric
    def type
      if self.is_a? Integer
        if self <= I32::MAX
          'i32'
        elsif self <= I64::MAX
          'i64'
        else
          raise "Integer value too large #{self}"
        end
      elsif self.is_a? Float
        if self <= F32::MAX
          'f32'
        elsif self <= F64::MAX
          'f64'
        else
          raise "Float value too large #{self}"
        end  
      else
        raise "Unknown value type #{self.class} for #{self}"
      end
    end
  end

  DEFAULT = Type::I32

end
