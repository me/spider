class Date
    def as_json
        strftime("%Y-%m-%d")
    end 
end

def Time
    def as_json
        xmlschema
    end
end

def Symbol
    def as_json
        to_s
    end
end

class Numeric
  def to_json(options = nil) #:nodoc:
    to_s
  end

  def as_json(options = nil) #:nodoc:
    self
  end
end

class Float
  def to_json(options = nil) #:nodoc:
    to_s
  end
end

class Integer
  def to_json(options = nil) #:nodoc:
    to_s
  end
end

require 'bigdecimal'
BigDecimal.class_eval do
   def to_json(options = nil) #:nodoc:
       to_f.to_json
   end
end