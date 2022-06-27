# Rlang language, compiler and libraries
# Copyright (c) 2019-2022,Laurent Julliard and contributors
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
  include Log

  WASM_TYPE_MAP = {
    UI64: Type::UI64,
    I64:  Type::I64,
    UI32: Type::UI32,
    I32:  Type::I32,
    F64:  Type::F64,
    F32:  Type::F32
  }

  # Implicit Type cast order in decreasing order of precedence
  # Class types have precedence over default integer type
  # because of pointer arithmetics
  CAST_PRECEDENCE = [:F64, :F32, :UI64, :I64, :Class, :UI32, :I32]
  
  attr_reader :name

  def self.legit?(name)
    WASM_TYPE_MAP.has_key? name
  end

  def self.leading(wtypes)
    logger.debug "wtypes: #{wtypes}"
    # The compact below is to remove the nil 
    # when wtype is blank or class
    leading_idx = wtypes.map {|wt| wt.class? ? :Class : wt.name}. \
      map {|wtn| CAST_PRECEDENCE.index(wtn) }.compact.each_with_index.min.last
    wtypes[leading_idx]
  end

  # Name is a symbol of the form :A or :"A::B" or :"A::B::C"
  # or a string "A" or "A::B" or "A::B::C"
  # or it can also be an array of symbols [:A], [:A, :B] or [:A, :B, :C]
  # (It is not a class object)
  def initialize(name)
    if name.is_a? Symbol
      @name = name
    elsif name.is_a? String
      @name = name.to_sym
    elsif name.is_a? Array
      @name = name.map(&:to_s).join('::').to_sym
    else
      raise "Unknown type for WType name (got #{name}, class: #{name.class}"
    end
    raise "Invalid WType #{name.inspect}" unless self.valid?
  end

  def class_path
    return [] if self.blank?
    name.to_s.split('::').map(&:to_sym)
  end

  def default?
    @name == WType::DEFAULT.name
  end

  def valid?
    self.blank? || self.native? || self.class?
  end

  def native?
    WASM_TYPE_MAP.has_key? @name
  end

  def signed?
    self.native? && WASM_TYPE_MAP[@name].signed?
  end
  
  def float?
    self.native? && WASM_TYPE_MAP[@name].float?
  end

  def blank?
    @name == :none || @name == :nil
  end

  def class?
    # name starts with uppercase and is not a native type
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

  # Define WType::xxxx constants for native types
  UI32 = self.new(:UI32)
  I32  = self.new(:I32)
  UI64 = self.new(:UI64)
  I64  = self.new(:I64)
  F32  = self.new(:F32)
  F64  = self.new(:F64)
  DEFAULT = self.new(WASM_TYPE_MAP.key(Type::DEFAULT))
  UNSIGNED_DEFAULT = self.new(WASM_TYPE_MAP.key(Type::UNSIGNED_DEFAULT))

end


