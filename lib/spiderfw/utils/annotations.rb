module Annotations

    def self.included(klass)
        klass.extend(ClassMethods)
        if (klass.is_a?(Module))
            klass.instance_eval do
                def included(klass)
                    if (@defined_annotations)
                        @defined_annotations.each do |name, proc|
                            klass.define_annotation(name, &proc)
                        end
                    end
                    @annotations.each do |method, vals|
                        vals.each do |k, args|
                            klass.annotate(method, k, *args)
                        end
                    end
                    super
                end
            end
        end
        super
    end

    class Annotator

        def initialize(owner) 
            @owner = owner
            @annotations = {}
            @pending_annotations = {}
            @m_pending_annotations = {}
            @pending = @pending_annotations
        end
        
        def pending
            r = @m_pending_annotations.merge(@pending_annotations)
            a = 3
            return r
        end
        
        def clear_pending
            @pending_annotations.each_key{ |k| @pending_annotations.delete(k) }
        end

        def method_missing(name, *args)
            @pending[name] = args
        end

        def annotate(method_name, *args)
            @owner.annotations[method_name] = hash
        end
        
        def single
            @pending = @pending_annotations
            return self
        end
        
        def multiple
            @pending = @m_pending_annotations
            return self
        end
        



    end


    module ClassMethods

        def __(m_name=nil, &proc)
            @annotator ||= Annotator.new(self).single
        end
        
        def ___()
            @annotator ||= Annotator.new(self).multiple
        end

        def method_added(name)
            return super unless @annotator
            @annotations ||= {}
            @annotations[name] ||= {}
            @annotator.pending.each do |key, args|
                annotate(name, key, args)
            end
            @annotator.clear_pending
            # debugger
            # self.method(name).annotations = @annotations[name]
            super
        end
        
        def annotate(method, name, *args)
            @annotations ||= {}
            @annotations[method] ||= {}
            if (args.length == 0)
                @annotations[method][name] = true
            elsif (args[0].is_a?(Hash))
                @annotations[method][name] = args[0]
            else
                @annotations[method][name] = args
            end
            ann = find_defined_annotation(name)
            if (ann)
                ann.call(self, method, *args)
            end
        end

        def define_annotation(name, &proc)
            @defined_annotations ||= {}
            @defined_annotations[name] = proc
            if (@annotations)
                @annotations.each do |method, n|
                    proc.call(self, method, *@annotations[method][n]) if n == name
                end
            end
        end
        
        def defined_annotations
            @defined_annotations
        end

        def find_defined_annotation(name)
            return nil if self.class == Module
            k = self
            while (k != Object)
                return nil unless k < Annotations
                return k.defined_annotations[name] if k.defined_annotations && k.defined_annotations[name]
                k = k.superclass
            end
        end



    end


end
# 
# class Method
#     attr_accessor :annotations
# end