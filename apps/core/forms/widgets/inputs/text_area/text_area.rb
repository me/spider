module Spider; module Forms
    
    class TextArea < Input
        tag 'textarea'
        is_attr_accessor :rows, :type => Fixnum, :default => 6
        is_attr_accessor :cols, :type => Fixnum, :default => 80

    end
    
end; end