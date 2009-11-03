class Class
    
    # def parent_module(n=1)
    #     return const_get_full(self.to_s.reverse.split('::', n+1)[n].reverse)
    # end
    
    def subclass_of?(klass)
        self < klass
    end
    
    # From ActiveSupport 2.3.4
    #Copyright (c) 2004-2009 David Heinemeier Hansson
    
    def cattr_reader(*syms)
      syms.flatten.each do |sym|
        next if sym.is_a?(Hash)
        class_eval(<<-EOS, __FILE__, __LINE__)
          unless defined? @@#{sym}  # unless defined? @@hair_colors
            @@#{sym} = nil          #   @@hair_colors = nil
          end                       # end
                                    #
          def self.#{sym}           # def self.hair_colors
            @@#{sym}                #   @@hair_colors
          end                       # end
                                    #
          def #{sym}                # def hair_colors
            @@#{sym}                #   @@hair_colors
          end                       # end
        EOS
      end
    end

    def cattr_writer(*syms)
      options = syms.last.is_a?(::Hash) ? syms.pop : {}
      syms.flatten.each do |sym|
        class_eval(<<-EOS, __FILE__, __LINE__)
          unless defined? @@#{sym}                       # unless defined? @@hair_colors
            @@#{sym} = nil                               #   @@hair_colors = nil
          end                                            # end
                                                         #
          def self.#{sym}=(obj)                          # def self.hair_colors=(obj)
            @@#{sym} = obj                               #   @@hair_colors = obj
          end                                            # end
                                                         #
          #{"                                            #
          def #{sym}=(obj)                               # def hair_colors=(obj)
            @@#{sym} = obj                               #   @@hair_colors = obj
          end                                            # end
          " unless options[:instance_writer] == false }  # # instance writer above is generated unless options[:instance_writer] == false
        EOS
      end
    end

    def cattr_accessor(*syms)
      cattr_reader(*syms)
      cattr_writer(*syms)
    end
    
end
