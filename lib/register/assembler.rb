
module Register
  class LinkSlot
    def initialize o 
      @position = -1
      @length = -1
      @objekt = o
    end
    attr_reader :objekt
    attr_accessor :position , :length , :layout
    def position
      raise "position accessed but not set at #{length} for #{self.objekt}" if @position == -1
      @position
    end
  end

  # Assmble the object space into a binary.
  # Link first to get positions, then assemble
  # link and assemble functions for each class are close to each other, so to get them the same.
  #  meaning: as the link function determines the length of an object and the assemble actually writes the bytes
  #           they are pretty much dependant. In an earlier version they were functions on the objects, but now it
  #           has gone to a visitor pattern.
  class Assembler
    TYPE_REF =  0
    TYPE_INT =  1
    TYPE_BITS = 4
    TYPE_LENGTH = 6
    
    def initialize space
      @space = space
      @objects = {}
    end
    attr_reader :objects

    def link
      collect_object(@space)
      at = 0
      @objects.each do |id , slot|
        next unless slot.objekt.is_a? Virtual::CompiledMethod
        slot.position = at
        slot.objekt.set_position at
        at += slot.length
      end
      @objects.each do |id , slot|
        next if slot.objekt.is_a? Virtual::CompiledMethod
        slot.position = at
        at += slot.length
      end
    end

    def assemble
      link
      @stream = StringIO.new
      @objects.each do |id , slot|
        next unless slot.objekt.is_a? Virtual::CompiledMethod
        assemble_object( slot )
      end
      @objects.each do |id , slot|
        next if slot.objekt.is_a? Virtual::CompiledMethod
        assemble_object( slot )
      end
      puts "Assembled #{@stream.length.to_s(16)}"
      return @stream.string
    end

    def collect_object(object)
      slot = @objects[object.object_id]
      return slot.length if slot
      slot = LinkSlot.new object
      @objects[object.object_id] = slot
      slot.layout = layout_for(object)
      collect_object(slot.layout[:names])
      clazz = object.class.name.split("::").last
      slot.length = send("collect_#{clazz}".to_sym , object)
    end

    def assemble_object slot
      obj = slot.objekt
      puts "Assemble #{obj.class}(#{obj.object_id}) at stream #{(@stream.length).to_s(16)} pos:#{slot.position.to_s(16)} , len:#{slot.length}" 
      raise "Assemble #{obj.class} at #{@stream.length.to_s(16)} not #{slot.position.to_s(16)}" if @stream.length != slot.position
      clazz = obj.class.name.split("::").last
      send("assemble_#{clazz}".to_sym , slot)
      slot.position
    end

    def type_word array
      word = 0
      array.each_with_index do |var , index|
        type = (var.class == Integer) ? TYPE_INT : TYPE_REF
        word +=  type << (index * TYPE_BITS)
      end
      word += ( (array.length + 1 ) / 8 ) << TYPE_LENGTH * TYPE_BITS
      word
    end

    # write type and layout of the instance, and the variables that are passed
    # variables ar values, ie int or refs. For refs the object needs to save the object first
    def assemble_self( object , variables )
      slot = get_slot(object)
      raise "Object(#{object.object_id}) not linked #{object.inspect}" unless slot
      type = type_word(variables)
      @stream.write_uint32( type )
      layout = slot.layout
      write_ref_for(layout[:names] , slot )
      variables.each do |var|
        write_ref_for(var , slot)
      end
      pad_after( variables.length * 4 )
      slot.position
    end

    def collect_Array( array )
      # also array has constant overhead, the padded helper fixes it to multiple of 8
      array.each do |elem| 
        collect_object(elem)
      end
      padded_words(array.length)
    end

    def assemble_Array slot
      array = slot.objekt
      layout = slot.layout
      type = type_word(array)
      @stream.write_uint32( type )
      write_ref_for(layout[:names],slot)  #ref
      array.each do |var|
        write_ref_for(var,slot)
      end
      pad_after( array.length * 4 )
      slot.position
    end

    def collect_Hash( hash )
      slot = get_slot(hash)
      #hook the key/values arrays into the layout (just because it was around)
      collect_object(slot.layout[:keys])
      collect_object(slot.layout[:values])
      padded_words(2)
    end

    def assemble_Hash slot
      # so here we can be sure to have _identical_ keys/values arrays
      assemble_self( slot.objekt , [ slot.layout[:keys] , slot.layout[:values] ] )
    end

    def collect_BootSpace(space)
      collect_object(space.classes)
      collect_object(space.objects)
      padded_words( 2 )
    end

    def assemble_BootSpace(slot)
      space = slot.objekt
      assemble_self(space , [space.classes,space.objects] )
    end

    def collect_BootClass(clazz)
      collect_object(clazz.name )
      collect_object(clazz.super_class_name)
      collect_object(clazz.instance_methods)
      padded_words(3)
    end

    def assemble_BootClass(slot)
      clazz = slot.objekt
      assemble_self( clazz , [clazz.name , clazz.super_class_name, clazz.instance_methods] )
    end

    def collect_CompiledMethod(method)
      # NOT an ARRAY, just a bag of bytes
      length = method.blocks.inject(0) { |c , block| c += block.length }
      padded(length)
    end


    def assemble_CompiledMethod(slot)
      method = slot.objekt
      count = method.blocks.inject(0) { |c , block| c += block.length }
      word = (count+7) / 32  # all object are multiple of 8 words (7 for header)
      raise "Method too long, splitting not implemented #{method.name}/#{count}" if word > 15
      # first line is integers, convention is that following lines are the same
      TYPE_LENGTH.times { word = ((word << TYPE_BITS) + TYPE_INT) }
      @stream.write_uint32( word )
      write_ref_for(slot.layout[:names] , slot)  #ref of layout
      # TODO the assembly may have to move to the object to be more extensible
      method.blocks.each do |block|
        block.codes.each do |code|
          code.assemble( @stream , self )
        end
      end
      pad_after( count )
    end

    def collect_String( str)
      return padded( str.length + 1 )
    end

    def collect_Symbol(sym)
      return collect_String(sym.to_s)
    end

    def collect_StringConstant(sc)
      return collect_String(sc.string)
    end

    def assemble_String( slot )
      str = slot.objekt
      str = str.string if str.is_a? Virtual::StringConstant
      str = str.to_s if str.is_a? Symbol
      layout = slot.layout
      word = (str.length + 7) / 32  # all object are multiple of 8 words (7 for header)
      raise "String too long (implement split string!) #{word}" if word > 15
      # first line is integers, convention is that following lines are the same
      TYPE_LENGTH.times { word = ((word << TYPE_BITS) + TYPE_INT) }
      @stream.write_uint32( word )
      write_ref_for( slot.layout[:names] , slot) #ref
      @stream.write str
      pad_after(str.length)
      #puts "String (#{slot.length}) stream #{@stream.length.to_s(16)}"
    end

    def assemble_Symbol(sym)
      return assemble_String(sym)
    end

    def assemble_StringConstant( sc)
      return assemble_String(sc)
    end

    private 
    def get_slot(object)
      slot = @objects[object.object_id]
      return slot if slot
      if(object.is_a? Array)
        @objects.each do |k,slot|
          next unless slot.objekt.is_a? Array
          if(slot.objekt.length == object.length)
            same = true
            slot.objekt.each_with_index do |v,index|
              same = false unless v == object[index]
            end
            puts slot.objekt.first.class if same
            return slot if same
          end
        end
      end
      nil
    end

    # write means we write the resulting address straight into the assembler stream (ie don't return it)
    # ref means the object of which we write the address
    # and we write the address into the self, given as second parameter
    def write_ref_for object , self_slot
      slot = get_slot(object)
      raise "Object (#{object.object_id}) not linked #{object.inspect}" unless slot
      @stream.write_sint32 slot.position
    end

    # objects only come in lengths of multiple of 8 words
    # but there is a constant overhead of 2 words, one for type, one for layout
    # and as we would have to subtract 1 to make it work without overhead, we now have to add 7
    def padded len
      a = 32 * (1 + (len + 7)/32 )
      #puts "#{a} for #{len}"
      a
    end

    def padded_words words
      padded(words*4) # 4 == word length, a constant waiting for a home
    end

    # pad_after is always in bytes and pads (writes 0's) up to the next 8 word boundary
    def pad_after length
      length += 8 # for header, type and layout
      pad = padded(length) - length
      pad.times do
        @stream.write_uint8(0)
      end
      #puts "padded #{length} with #{pad} stream pos #{@stream.length.to_s(16)}"
    end

    # class variables to have _identical_ objects passed back (stops recursion)
    @@ARRAY =  { :names => [] , :types => []}
    @@HASH = { :names => [:keys,:values] , :types => [Virtual::Reference,Virtual::Reference]}
    @@CLAZZ = { :names => [:name , :super_class_name , :instance_methods] , :types => [Virtual::Reference,Virtual::Reference,Virtual::Reference]}
    @@SPACE = { :names => [:classes,:objects] , :types => [Virtual::Reference,Virtual::Reference]}

    def layout_for(object)
      case object
      when Array , Symbol , String , Virtual::CompiledMethod , Virtual::Block , Virtual::StringConstant
        @@ARRAY
      when Hash
        @@HASH.merge :keys => object.keys , :values => object.values 
      when Virtual::BootClass
        @@CLAZZ
      when Virtual::BootSpace
        @@SPACE
      else
        raise "linker encounters unknown class #{object.class}"
      end
    end
  end

  Sof::Volotile.add(Register::Assembler , [:objects])
end