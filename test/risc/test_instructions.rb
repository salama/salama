require_relative "../helper"

module Risc
  class TestInstructions < MiniTest::Test
    def setup
      @label = Label.new("test" , "test",nil)
      @branch = Branch.new("test" , @label)
      @instruction = Instruction.new("test")
    end
    def test_branch_tos1
      assert @branch.to_s.include?("Branch")
      assert @branch.to_s.include?("test")
    end
    def test_branch_tos2
      branch = Branch.new(nil ,nil)
      assert branch.to_s.include?("Branch")
    end
    def test_label_tos1
      assert @label.to_s.include?("Label")
    end
    def test_label_tos2
      assert Label.new(nil,nil,nil).to_s.include?("Label")
    end
    def test_last_empty
      assert_equal @instruction, @instruction.last
    end
    def test_last_not_empty
      @instruction.set_next @branch
      assert_equal @branch, @instruction.last
    end
    def test_append_empty
      @instruction.append @branch
      assert_equal @branch, @instruction.last
    end
    def test_insert
      @instruction.insert @branch
      assert_equal @branch, @instruction.last
    end
    def test_insert_two
      @branch << @label
      @instruction.insert @branch
      assert_equal @label , @instruction.last
    end
    def test_append_not_empty
      @instruction.append @branch
      @instruction.append @label
      assert_equal @label, @instruction.last
    end
    def test_next1
      assert_nil  @instruction.next
    end
    def test_next2
      @instruction.set_next @label
      assert_equal @label , @instruction.next
      assert_nil  @instruction.next(2)
    end
    def test_label_is_method
      label = Label.new("test" , "Object.test" , nil)
      assert label.is_method
    end
    def test_label_is_not_method
      assert ! @label.is_method
    end
    def test_insert_self
      assert_raises {@label.insert(@label)}
    end
  end
end
