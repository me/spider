# Module to allow annotations on methods. When included into a Class or Module,
# will make the Annotations::ClassMethods.__ and Annotations::ClassMethods.\___ methods available. 
# These can be used before a method to add annotations.
# The including class can also use Annotations::ClassMethods.define_annotation to define code
# that will be executed when an annotation is encountered.
#
# Example:
#   class A
#     include Annotations
#
#     def self.cool_methods; @cool_methods ||= []; end
#     
#     define_annotation :method_rating do |klass, method, args|
#       klass.cool_methods << method if args[0] == :cool
#     end
#     
#     __.is_first_method
#     def method1
#     end
#
#   ___.is_other_method
#     def method2
#     end
#     
#     __.method_rating :cool
#     def method3
#     end
#
#   end
#   
#   p A.annotations[:method1] => {:is_first_method => true} 
#   p A.annotations[:method3] => {:is_other_method => true, :method_rating => :cool}
#   p A.cool_methods => [:method3]
#
# *Warning*: annotations are *not* thread safe; if more than one file is being loaded at the same time for
# the same Module, annotations may end up wrong.
# You should ensure that all code using annotations is loaded in a single thread (this is usually a good idea anyway).

module Annotations

    def self.included(klass)
        klass.extend(ClassMethods)
        unless klass.is_a?(Class)
            klass.instance_eval do
                alias annotations_original_append_features append_features
                def append_features(kl)
                    result = annotations_original_append_features(kl)
                    if (@defined_annotations)
                        @defined_annotations.each do |name, proc|
                            kl.define_annotation(name, &proc)
                        end
                    end
                    @annotations ||= {}
                    @annotations.each do |method, vals|
                        vals.each do |k, args|
                            args = [args] unless args.is_a?(Array)
                            kl.annotate(method, k, *args)
                        end
                    end
                    result
                end
            end
        end
        super
    end

    # @private
    class Annotator

        def initialize(owner) 
            @owner = owner
            @annotations = {}
            @pending_annotations = []
            @m_pending_annotations = []
            @pending = @pending_annotations
        end
        
        def pending
            r = @m_pending_annotations + @pending_annotations
            return r
        end
        
        def clear_pending
            @pending_annotations.clear
        end

        def method_missing(name, *args)
            @pending << [name, args]
        end

        def annotate(method_name, *args)
            @owner.annotations[method_name] = args
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
        
        def inherited(subclass)
            if (@annotations)
                @annotations.each do |method, vals|
                    vals.each do |k, args|
                        args = [args] unless args.is_a?(Array)
                        subclass.annotate(method, k, *args)
                    end
                end
            end
            super
        end
        
        # Returns the @annotations Hash.
        def annotations
            @annotations
        end

        # Annotates the next method.
        def __()
            @annotator ||= Annotator.new(self).single
        end
        
        # Annotates all the following methods, until the end of the Class/Module.
        def ___()
            @annotator ||= Annotator.new(self).multiple
        end

        def method_added(name) # :nodoc:
            return super unless @annotator
            @annotations ||= {}
            @annotations[name] ||= {}
            @annotator.pending.each do |key, args|
                annotate(name, key, *args)
            end
            @annotator.clear_pending
            # debugger
            # self.method(name).annotations = @annotations[name]
            super
        end
        
        # Explicitly annotates a method
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
        
        # Defines an annotation. The given block will be called whenever the "name" annotation
        # is encountered; it will be passed the current Class, the annotated Method, and the annotation arguments.
        def define_annotation(name, &proc)
            @defined_annotations ||= {}
            @defined_annotations[name] = proc
            if (@annotations)
                @annotations.each do |method, n|
                    proc.call(self, method, *@annotations[method][n]) if n == name
                end
            end
        end
        
        # Returns the Hash of defined annotations.
        def defined_annotations
            @defined_annotations
        end

        # Searches for a defined annotation in class and ancestors.
        def find_defined_annotation(name)
            return nil if self.class == Module && !@defined_annotations
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