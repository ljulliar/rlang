require_relative '../rlang/parser/ext/type'

class Global

  @@globals = {}

  attr_reader :key, :value, :wtype
  
  def initialize(key, value, wtype = Type::DEFAULT_TYPE, mutable: true)
    raise "Can't initialize same Global twice #{key}" \
      if @@globals.has_key? key
    @key = key
    @value = value
    @@globals[key] = self
    @wtype = wtype
    @mutable = mutable
  end

  def []= (key, value)
    raise "Cannot modify unmutable global #{@key}" unless self.mutable?
  end

  def [] (key)
    @@globals[key].value
  end

  def mutable?
    @mutable
  end

  def self.has_key?(key)
    @@globals.has_key? key
  end

  def self.find_gvar(key)
    @@globals[key]
  end
end