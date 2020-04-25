require_relative '../../utils/log'
require_relative './ext/string'
require_relative './wtype'
require_relative './ext/integer'


# Don't use class name Data because it's a deprecated
# Ruby class and it generates warning at runtime
module Rlang::Parser
  class DAta
    include Log

    TMPL = '(data 0 (i32.const %{addr}) "%{value}") ;; %{comment}'

    @@label_table = {}
    @@current_address = 0

    attr_reader :label, :wtype, :address, :value

    # NOTE: new and append only takes individual DAta values
    # not an array of values
    # TODO: fix DAta.new and DAta.append not accepting an array of values
    def initialize(label, value, wtype=WType::DEFAULT)
      raise "Data label '#{label}' already initialized" \
        if self.class.exist? label
      logger.debug "@@current_address: #{@@current_address}"
      @label = label
      @wtype = wtype
      @address = @@current_address
      @@label_table[@label] = self
      @value = []
      self.append_value(value, wtype)
      logger.debug "New Data[#{@label}] initialized with #{@value} at address #{@address} / new current address: #{@@current_address}"
    end

    def self.reset!
      @@label_table = {}
      @@current_address = 0
    end

    def append_value(value, wtype)
      @value << value
      if value.is_a? String
        @@current_address += value.length
      else
        logger.warn "Data type #{@wtype} misaligned!!! (Data[:#{@label}] value #{value} at address #{@address}" \
          unless self.aligned?
        @@current_address += @wtype.size
      end
    end

    def aligned?
      (@@current_address % @wtype.size) == 0
    end

    def self.exist?(label)
      @@label_table.has_key? label
    end

    def self.[](label)
      raise "Unknown data label '#{label}'" unless self.exist? label
      @@label_table[label].address
    end

    def self.append(label, value, wtype=WType::DEFAULT)
      logger.debug "appending #{value} to DAta[#{label}]"
      if self.exist? label
        @@label_table[label].append_value(value, wtype)
      else
        self.new(label, value, wtype)
      end
    end

    def self.address=(address)
      logger.fatal "ERROR!! Cannot decrease current DAta address (was #{@@current_address}, got #{address}) " \
        if address < @@current_address
      @@current_address = address
    end

    # Align current address to closest multiple of
    # n by higher value
    def self.align(n)
      if (m = @@current_address % n) != 0
        @@current_address = (@@current_address - m) + n
      end
      logger.debug "Aligning current address to #{@@current_address}"
      @@current_address
    end

    # Transpile data to WAT code
    # in order of increasing address
    def self.transpile
      output = []
      @@label_table.sort_by {|s,d| d.address}.each do |s,d|
        logger.debug "Generating data #{d.inspect}"
        address = d.address
        d.value.each do |elt|
          if elt.is_a? String
            output << TMPL % {addr: address, value: elt.to_wasm, comment: s}
            address += d.value.size
          elsif elt.is_a? Integer
            output << TMPL % {addr: address, value: elt.to_little_endian(d.wtype.size), comment: "(#{elt} #{s})"}
            address += d.wtype.size
          elsif elt.is_a? DAta
            output << TMPL % {addr: address, value: elt.address.to_little_endian(d.wtype.size), comment: "(#{elt} #{s})"}
            address += d.wtype.size
          else
            raise "Unknown Data type: #{value.class}"
          end
        end
      end
      output.join("\n")
    end
  end

end