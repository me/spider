require 'delegate'

module Spider; module DataTypes

    class TimeSpan < DelegateClass(Fixnum)
        include DataType
        maps_to Fixnum
        
        def format(f=nil)
            if self % 3600 == 0
                val = self / 3600
                "#{val} " + (val == 1 ? _('hour') : _('hours') )
            elsif self % 60 == 0
                val = self / 60
                "#{val} " + (val == 1 ? _('minute') : _('minutes') )
            else
                val = self
                "#{val} " + (val == 1 ? _('second') : _('seconds') )
            end
        end
        

    end
    
    
end; end
