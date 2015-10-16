require_relative "compiler_helper"

module Virtual
  class TestOps < MiniTest::Test
    include CompilerHelper

    def setup
      Virtual.machine.boot
      @root = :operator_value
      @output = Register::RegisterValue
    end

    def operators
      ["+" , "-" , "*" , "/" , "=="]
    end
    def test_ints
      operators.each do |op|
        @string_input = '2 + 3'.sub("+" , op)
        check
      end
    end
    def test_local_int
      Virtual.machine.space.get_main.ensure_local(:bar , :Integer)
      @string_input    = 'bar  + 3'
      check
    end
    def test_int_local
      Virtual.machine.space.get_main.ensure_local(:bar , :Integer)
      @string_input    = '3  + bar'
      check
    end

    def test_field_int
      Virtual.machine.space.get_class_by_name(:Object).object_layout.add_instance_variable(:bro)
      @string_input = "self.bro + 3"
      check
    end

    def test_int_field
      Virtual.machine.space.get_class_by_name(:Object).object_layout.add_instance_variable(:bro)
      @string_input = "3 + self.bro"
      check
    end
  end
end