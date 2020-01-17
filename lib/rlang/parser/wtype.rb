# Rubinius WebAssembly VM
# Copyright (c) 2019, Laurent Julliard and contributors
# All rights reserved.

# WType class. This class manages the wtype
# of Wnode objects. This is a higher level 
# representation of WASM types
#
# A wtype can be initialized with values like
# - :none or :nil : no type defined
# - A legit WASM type :I32, : I64,....
# - or a Rlang class name

require_relative '../../utils/log'
require_relative './ext/type'

class WType

  WASM_TYPE_MAP = {
    I64: Type::I64,
    I32: Type::I32,
    F64: Type::F64,
    F32: Type::F32
  }

  # Type cast order in decreading order of precedence
  CAST_PRECEDENCE = [:F64, :F32, :I64, :I32]

  attr_reader :name

  def self.legit?(name)
    WASM_TYPE_MAP.has_key? name
  end

  def self.leading(wtypes)
    logger.debug "wtypes: #{wtypes}"
    # The compact below is to remove the nil 
    # when wtype is blank or class
    leading_idx = wtypes.map { |wt| CAST_PRECEDENCE.index(wt.name) }.compact.each_with_index.min.last
    wtypes[leading_idx]
  end

  def initialize(name)
    @name = name.to_sym
    raise "Invalid WType #{name.inspect}" unless self.valid?
  end

  def valid?
    self.blank? || self.native? || self.class?
  end

  def native?
    WASM_TYPE_MAP.has_key? @name
  end

  def blank?
    @name == :none || @name == :nil
  end

  def class?
    !self.native? && ('A'..'Z').include?(@name.to_s[0])
  end

  def ==(other)
    @name == other.name
  end

  def size
    if self.blank?
      0
    elsif self.native?
      WASM_TYPE_MAP[@name].size
    else
      Type::DEFAULT.size
    end
  end

  # returns a String with the proper WASM type
  # that can be used for code generation
  def wasm_type
    if self.blank?
      ''
    elsif self.native?
      WASM_TYPE_MAP[@name].wasm_type
    elsif self.class?
      # it's a class name return DEFAULT WASM
      # type because this is always the class of
      # amemory address in VASM VM
      Type::DEFAULT.wasm_type
    else
      raise "Unknown WType #{self.inspect}"
    end
  end

  def to_s
    ":#{@name}"
  end

  def inspect
    self.to_s
  end

  DEFAULT = self.new(WASM_TYPE_MAP.key(Type::DEFAULT))

end


