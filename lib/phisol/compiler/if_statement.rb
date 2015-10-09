module Phisol
  Compiler.class_eval do
#    if - attr_reader  :cond, :if_true, :if_false

    def on_if_statement statement
      condition , if_true , if_false = *statement
      condition = condition.first
      # to execute the logic as the if states it, the blocks are the other way around
      # so we can the jump over the else if true ,
      # and the else joins unconditionally after the true_block
      merge_block = @method.source.new_block "if_merge"    # last one, created first
      true_block =  @method.source.new_block "if_true"     # second, linked in after current, before merge
      false_block = @method.source.new_block "if_false"    # directly next in order, ie if we don't jump we land here

      is = process(condition)
      # TODO should/will use different branches for different conditions.
      # just a scetch : cond_val = cond_val.is_true?(method) unless cond_val.is_a? BranchCondition
      @method.source.add_code Register::IsZeroBranch.new( condition , true_block )

      # compile the true block (as we think of it first, even it is second in sequential order)
      @method.source.current true_block

      last = process_all(if_true).last

      # compile the false block
      @method.source.current false_block
      last = process_all(if_false).last if if_false
      @method.source.add_code Register::AlwaysBranch.new(statement, merge_block )

      #puts "compiled if: end"
      @method.source.current merge_block

      #TODO should return the union of the true and false types
      last
    end
  end
end
