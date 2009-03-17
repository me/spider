module Spider; module Forms
    
    class Text < Input
        tag 'text'
        is_attr_accessor :size, :type => Fixnum, :default => 25

    end
    
end; end