require_relative 'helper'

module Risc
  class TestAssignIvarConst < MiniTest::Test
    include Statements

    def setup
      super
      @input = "@ivar = 5"
      @expect = [LoadConstant, SlotToReg, RegToSlot]
    end
    def test_local_assign_instructions
      assert_nil msg = check_nil , msg
    end

    def test_constant_load
      produced = produce_body
      assert_equal 5 , produced.constant.known_object.value
    end

    def test_slot_move
      produced = produce_body
      assert_equal produced.next.next.register , produced.register
    end

    def test_load_self_from_message
      produced = produce_body
      assert_equal :r0 , produced.next.array.symbol , produced.next.to_rxf
      assert_equal 3 , produced.next.index , produced.next.to_rxf
    end

  end
end
