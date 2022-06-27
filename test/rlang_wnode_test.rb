# Rlang language, compiler and libraries
# Copyright (c) 2019-2022, Laurent Julliard and contributors
# All rights reserved.

require 'test_helper'
require_relative '../lib/rlang/parser/wnode'

class RlangWNodeTest < Minitest::Test

  include Rlang::Parser
  include Log
  logger.level = Logger::FATAL

  def setup
    @root = WNode.new(:root)
  end

  def test_root
    assert_nil @root.parent
    assert_equal :root, @root.type
    assert @root.root?
  end

  def test_new_child
    wn = WNode.new(:none, @root)
    assert_equal @root, wn.parent
    assert_equal [], wn.children
  end

  def test_10_new_children
    wn_new = []
    10.times { wn_new << WNode.new(:none, @root) }
    assert_equal wn_new, @root.children
  end

  def test_add_children
    @root << (wn1 = WNode.new(:none))
    wn1 << (wn20 = WNode.new(:none))
    wn1 << (wn21 = WNode.new(:insn))
    assert_equal 1, @root.children.count
    assert_equal [wn1], @root.children
    assert_equal 2, wn1.children.count
    assert_equal [wn20, wn21], wn1.children
    assert_equal :none, wn1.children[0].type
    assert_equal :insn, wn1.children[1].type
  end

  def test_three_levels_tree
    @root << (wn1 = WNode.new(:none))
    wn1 << (wn2 = WNode.new(:insn))
    wn2 << (wn3 = WNode.new(:insn))
    assert_equal 1, @root.children.count
    assert_equal 1, @root.children.first.children.count
    assert_equal 1, @root.children.first.children.first.children.count
    assert_equal 0, @root.children.first.children.first.children.first.children.count
  end

  def test_remove_child
    @root << (wn1 = WNode.new(:none))
    wn1 << (wn20 = WNode.new(:insn))
    wn1 << (wn21 = WNode.new(:insn))
    wn1 << (wn22 = WNode.new(:insn))
    assert_equal 1, @root.children.count
    assert_equal 3, wn1.children.count
    # remove child 21
    assert_equal wn21, wn1.remove_child(wn21)
    assert_equal 2, wn1.children.count
    assert_equal [wn20, wn22], wn1.children
    assert_nil wn21.parent
    assert_empty wn21.children
    assert_nil wn1.children.find { |wn| wn == wn21}
    # remove child 22
    assert_equal wn22, wn1.remove_child(wn22)
    assert_equal 1, wn1.children.count
    assert_equal [wn20], wn1.children
    assert_nil wn22.parent
    assert_empty wn22.children
    # remove child 20
    assert_equal wn20, wn1.remove_child(wn20)
    assert_equal 0, wn1.children.count
    assert_equal [], wn1.children
    assert_nil wn20.parent
    assert_empty wn20.children
    # try removing child 20 again
    assert_raises { wn1.remove_child(wn20) }
    assert_equal 0, wn1.children.count
    assert_equal [], wn1.children
  end

  def test_reparent_child
    @root << (wn1 = WNode.new(:none))
    wn1 << (wn20 = WNode.new(:insn))
    wn1 << (wn21 = WNode.new(:insn))
    wn21 << (wn30 = WNode.new(:insn))
    wn21 << (wn31 = WNode.new(:insn))
    wn31 << (wn40 = WNode.new(:insn))
    wn31 << (wn41 = WNode.new(:insn))

    assert_equal 2, wn1.children.count
    assert_equal 2, wn21.children.count
    assert_equal 0, wn20.children.count
    assert_equal 2, wn31.children.count

    wn31.reparent_to(wn1)
    assert_equal 1, wn21.children.count
    assert_equal 3, wn1.children.count
    assert_equal [wn20, wn21, wn31], wn1.children
    assert_equal [wn40, wn41], wn31.children
    assert_equal wn1, wn31.parent

    wn30.reparent_to(wn1)
    assert_equal 0, wn21.children.count
    assert_equal 4, wn1.children.count
  end

  def test_reparent_children_to
    @root << (wn1 = WNode.new(:none))
    wn1 << (wn20 = WNode.new(:insn))
    wn1 << (wn21 = WNode.new(:insn))
    wn21 << (wn30 = WNode.new(:insn))
    wn21 << (wn31 = WNode.new(:insn))

    assert_equal 2, wn21.children.count
    assert_equal [wn20, wn21], wn1.children
    wn21.reparent_children_to(wn1)

    assert_equal 0, wn21.children.count
    assert_equal 4, wn1.children.count
    assert_equal [wn20, wn21, wn30, wn31], wn1.children
  end
end