# Symbol monkey patch.

class Symbol
    unless self.method_defined?(:to_proc)
        def to_proc
            proc { |obj, *args| obj.send(self, *args) }
        end
    end
end