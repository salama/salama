module Risc
  module Position

    # Instructions are also a linked list, but their position is not really
    # the position of the object.
    # Rather it is the position of the assembled code in the binary.
    # (Luckily arm is sane, so this is realtively simple)
    #
    # Really we only need to calculate Positions at a jump, so between the
    # Jump and the label it jumps too. The other instructions are "just" fill.
    # But off course we need to propagate positions to get it right.
    #
    # Assembled instructions are kept in BinaryCode objects.
    # When propagating positions we have to see that the next position assembles into
    # the same BinaryCode, or else move it and the code along
    #
    class InstructionPosition < ObjectPosition
      attr_reader :instruction , :binary
      def initialize(instruction , binary)
        pos = 0
        super(instruction)
        @instruction = instruction
        @binary = binary
      end
      def init(at, binary)
        @binary = binary
        instruction.address.set_value(at) if instruction.is_a?(Label)
        return if at == 0 and binary.nil?
        raise "faux pas" if at < Position.get(binary).at
        return unless @instruction.next
        nekst = at + @instruction.byte_length
        diff = nekst - Position.get(@binary).at
        Position.log.debug "Diff: #{diff.to_s(16)} , next #{nekst.to_s(16)} , binary #{Position.get(@binary)}"
        raise "Invalid position #{diff.to_s(16)} , next #{nekst.to_s(16)} #{self}" if diff < 8
        if( (diff % (binary.padded_length - @instruction.byte_length)) == 0 )
          binary.extend_one unless binary.next
          binary = binary.next
          raise "end of line " unless binary
          nekst = Position.get(binary).at + Parfait::BinaryCode.byte_offset
          Position.log.debug "Jump to: #{nekst.to_s(16)}"
        end
        Position.set(@instruction.next, nekst , binary)
      end

      def reset_to(pos , binary)
        super(pos , binary)
        init(pos , binary)
        Position.log.debug "ResetInstruction (#{pos.to_s(16)}) #{instruction}"
      end

      # initialize the dependency graph for instructions
      #
      # starting from the given instruction, create InstructionPositions
      # for it and the whole chain
      #
      # Set the next created to be dependent on the previous
      def self.init( instruction , code)
        while(instruction)
          position = InstructionPosition.new(instruction , code)
          nekst = instruction.next
          if nekst
            listener = InstructionListener.new( nekst )
            position.register_event(:position_changed , listener)
          end
          instruction = nekst
        end
        position
      end
    end
  end
end
