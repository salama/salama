require_relative "helper"

module SolBlocks
  class TestConditionIfSlotMachine < MiniTest::Test
    include SolCompile

    def setup
      @ins = compile_main_block( "if(5.div4) ; @a = 6 ; else; @a = 5 ; end" , "local=5", "Integer.div4")
    end

    def test_condition
      assert_equal TruthCheck , @ins.next(3).class
    end
    def test_condition_is_slot
      assert_equal SlottedMessage , @ins.next(3).condition.class , @ins
    end
    def test_simple_call
      assert_equal SimpleCall , @ins.next(2).class
      assert_equal :div4 , @ins.next(2).method.name
    end
    def test_array
      check_array [MessageSetup, ArgumentTransfer, SimpleCall, TruthCheck, Label ,
                    SlotLoad, Jump, Label, SlotLoad, Label ,
                    Label, ReturnSequence, Label] , @ins
    end

  end
end
