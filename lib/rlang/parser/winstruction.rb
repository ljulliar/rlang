# Rubinius WebAssembly VM
# Copyright (c) 2019, Laurent Julliard and contributors
# All rights reserved.
#
# WASM instructions data

module Rlang::Parser

  class WInstruction
    @@instructions = {}

    attr_reader :insn, :stk_ins, :stk_outs

    # inputs and outputs are respectively what an
    # instruction pops from the stack and what it
    # pushes back as a result
    def initialize(insn, stk_ins, stk_outs)
      @insn = insn
      @stk_ins = stk_ins
      @stk_outs = stk_outs
      @@instructions[insn] = self
    end

    def self.load(insn_data)
      insn_data.each { |elt| WInstruction.new(*elt) }      
    end
  end

  WInstruction.load(
  [
    ['unreachable', [:any], [:any]],
    ['nop', [], []],
    ['block', [], [:any]],
    ['loop', [], [:any]],
    ['if', [:I32], [:any]],
    ['then', [], [:any]],
    ['else', [], [:any]],
    ['br', [], []],
    ['br_if', [:I32], []],
    ['br_table', [:I32], []],
    ['return', [], [:any]],
    ['call', [:any], [:any]],
    ['call_indirect', [:any, :I32], [:any]],
    ['drop', [:any], []],
    ['select', [:one, :one, :I32], []],
    ['func', [], []],
    ['param', [], []],
    ['result', [], []],
    ['i32.load', [:I32], [:I32]],
    ['i64.load', [:I32], [:I64]],
    ['i32.load8_s', [:I32], [:I32]],
    ['i32.load8_u', [:I32], [:I32]],
    ['i32.load16_s', [:I32], [:I32]],
    ['i32.load16_u', [:I32], [:I32]],
    ['i64.load8_s', [:I32], [:I64]],
    ['i64.load8_u', [:I32], [:I64]],
    ['i64.load16_s', [:I32], [:I64]],
    ['i64.load16_u', [:I32], [:I64]],
    ['i64.load32_s', [:I32], [:I64]],
    ['i64.load32_u', [:I32], [:I64]],
    ['i32.store', [:I32, :I32], []],
    ['i64.store', [:I32, :I64], []],
    ['i32.store8', [:I32, :I32], []],
    ['i32.store16', [:I32, :I32], []],
    ['i64.store8', [:I32, :I64], []],
    ['i64.store16', [:I32, :I64], []],
    ['i64.store32', [:I32, :I64], []],
    ['memory.size', [], [:I32]],
    ['memory.grow', [:I32], [:I32]],
    ['i32.const', [], [:I32]],
    ['i64.const', [], [:I64]],
    ['i32.eqz', [:I32], [:I32]],
    ['i32.eq', [:I32, :I32], [:I32]],
    ['i32.lt_s', [:I32, :I32], [:I32]],
    ['i32.lt_u', [:I32, :I32], [:I32]],
    ['i32.gt_s', [:I32, :I32], [:I32]],
    ['i32.gt_u', [:I32, :I32], [:I32]],
    ['i32.le_s', [:I32, :I32], [:I32]],
    ['i32.le_u', [:I32, :I32], [:I32]],
    ['i32.ge_s', [:I32, :I32], [:I32]],
    ['i32.ge_u', [:I32, :I32], [:I32]],
    ['i64.eqz', [:I64], [:I32]],
    ['i64.eq', [:I64, :I64], [:I32]],
    ['i64.lt_s', [:I64, :I64], [:I32]],
    ['i64.lt_u', [:I64, :I64], [:I32]],
    ['i64.gt_s', [:I64, :I64], [:I32]],
    ['i64.gt_u', [:I64, :I64], [:I32]],
    ['i64.le_s', [:I64, :I64], [:I32]],
    ['i64.le_u', [:I64, :I64], [:I32]],
    ['i64.ge_s', [:I64, :I64], [:I32]],
    ['i64.ge_u', [:I64, :I64], [:I32]],
    ['call', [:any], [:any]],
    ['local.get', [], [:one]],
    ['local.set', [:one], []],
    ['local.tee', [:one], [:one]],
    ['global.get', [], [:one]],
    ['global.set', [:one], []],
    ['i32.clz', [:I32], [:I32]],
    ['i32.ctz', [:I32], [:I32]],
    ['i32.popcnt', [:I32], [:I32]],
    ['i32.add', [:I32, :I32], [:I32]],
    ['i32.sub', [:I32, :I32], [:I32]],
    ['i32.mul', [:I32, :I32], [:I32]],
    ['i32.div_s', [:I32, :I32], [:I32]],
    ['i32.div_u', [:I32, :I32], [:I32]],
    ['i32.rem_s', [:I32, :I32], [:I32]],
    ['i32.rem_u', [:I32, :I32], [:I32]],
    ['i32.and', [:I32, :I32], [:I32]],
    ['i32.or', [:I32, :I32], [:I32]],
    ['i32.or', [:I32, :I32], [:I32]],
    ['i32.xor', [:I32, :I32], [:I32]],
    ['i32.shl', [:I32, :I32], [:I32]],
    ['i32.shr_s', [:I32, :I32], [:I32]],
    ['i32.shr_u', [:I32, :I32], [:I32]],
    ['i32.rotl', [:I32, :I32], [:I32]],
    ['i32.rotr', [:I32, :I32], [:I32]],
    ['i64.clz', [:I64], [:I64]],
    ['i64.ctz', [:I64], [:I64]],
    ['i64.popcnt', [:I32], [:I32]],
    ['i64.add', [:I64, :I64], [:I64]],
    ['i64.sub', [:I64, :I64], [:I64]],
    ['i64.mul', [:I64, :I64], [:I64]],
    ['i64.div_s', [:I64, :I64], [:I64]],
    ['i64.div_u', [:I64, :I64], [:I64]],
    ['i64.rem_s', [:I64, :I64], [:I64]],
    ['i64.rem_u', [:I64, :I64], [:I64]],
    ['i64.and', [:I64, :I64], [:I64]],
    ['i64.or', [:I64, :I64], [:I64]],
    ['i64.or', [:I64, :I64], [:I64]],
    ['i64.xor', [:I64, :I64], [:I64]],
    ['i64.shl', [:I64, :I64], [:I64]],
    ['i64.shr_s', [:I64, :I64], [:I64]],
    ['i64.shr_u', [:I64, :I64], [:I64]],
    ['i64.rotl', [:I64, :I64], [:I64]],
    ['i64.rotr', [:I64, :I64], [:I64]],
    ['i32.wrap_64', [:I64], [:I32]],
    ['i64.extend_i32_s', [:I32], [:I64]],
    ['i64.extend_i32_u', [:I32], [:I64]],
    ['i64.trunc_f32_s', [:F32], [:I64]],
    ['i64.trunc_f32_u', [:F32], [:I64]],
    ['i64.trunc_f64_s', [:F64], [:I64]],
    ['i64.trunc_f64_u', [:F64], [:I64]],
    ['i64.trunc_f32_s', [:F64], [:I64]],
    ['i64.trunc_f32_u', [:F64], [:I64]],
  ] )

  end
end