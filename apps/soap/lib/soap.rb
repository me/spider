require 'soap/mapping/registry'
require 'soap/mapping/factory'
require 'soap/rpc/router'

module SOAP; module Mapping
    
    class Registry
        
        class Map
            def class2soap(klass)
                ancestors = klass.ancestors
                ancestors.delete(::Object)
                ancestors.delete(::Kernel)
                ancestors.each do |k|
                    return @obj2soap[k][0] if @obj2soap[k]
                end
                return nil
            end
        end
        
        def class2soap(klass)
            @map.class2soap(klass)
        end
        
    end
    
end; end
    
module Spider
    
    module Soap
        
        XsdNs             = 'http://www.w3.org/2001/XMLSchema'
        WsdlNs            = 'http://schemas.xmlsoap.org/wsdl/'
        SoapNs            = 'http://schemas.xmlsoap.org/wsdl/soap/'
        SoapEncodingNs    = 'http://schemas.xmlsoap.org/soap/encoding/'
        SoapHttpTransport = 'http://schemas.xmlsoap.org/soap/http'
        
        def self.included(klass)
            klass.extend(ClassMethods)
        end
        
        module ClassMethods
        
            def SoapArray(type)
                Class.new(SoapArray) do
                    @array_type = type
                end
            end
        
            def SoapStruct(elements)
                Class.new(SoapStruct) do
                    @elements = elements
                end
            end
            
        end
        
        class GenericStructFactory < SOAP::Mapping::Factory
            def initialize(qname)
                @qname = qname
            end
            
            def obj2soap(soap_class, obj, info, map)
                soap_obj = soap_class.new(@qname)
                info[:elements].each do |key, type|
                    value = obj[key.to_sym]
                    soap_obj[key.to_s] = SOAP::Mapping._obj2soap(value, map)
                end
                soap_obj
            end

            def soap2obj(obj_class, node, info, map)
                return false unless node.type == @qname
                obj = obj_class.new
                node.each do |key, value|
                    obj[key.to_sym] = value.data
                end
                return true, obj
            end
        end
        
        class CustomExceptionFactory < SOAP::Mapping::Factory
            
            def obj2soap(soap_class, obj, info, map)
                soap_obj = ::SOAP::SOAPStruct.new
                elename = ::SOAP::Mapping.name2elename("message")
                soap_obj.add elename, ::SOAP::Mapping._obj2soap(obj.message, map)
                soap_obj
            end
            
            def soap2obj(obj_class, node, info, map)
                return RuntimeError.new(node['message'].data)
            end
            
        end
        
        module SoapType
            def self.included(klass)
                klass.extend(ClassMethods)
            end
            
            module ClassMethods
                def qname
                    @soap_controller.type_to_qname(self)
                end
                
                def soap_controller=(c)
                    @soap_controller = c
                end
                
                def collect_soap_types
                    st = [self]
                    self.types.each do |t|
                        st += t.collect_soap_types if t < SoapType
                    end
                    return st
                end
            end
            
        end
        
        # FIXME:
        # SOAP marks the return as a generic array, not with our qtype
        # should probably use a custom factory
        class SoapArray < Array
            include SoapType
            
            def self.array_type
                @array_type
            end
            
            def self.types
                return [@array_type]
            end
            
            def self.soap_class
                SOAP::SOAPArray
            end
            
            def self.soap_factory
                SOAP::Mapping::Registry::TypedArrayFactory
            end

            def self.soap_info
                {
                    :type => @soap_controller.type_to_qname(array_type)
                }
            end

            def initialize(array)
                replace(array)
                if (self.class.array_type < SoapType)
                    self.each_index do |i|
                        self[i] = self.class.array_type.new(self[i]) unless self[i].is_a?(self.class.array_type)
                    end
                end
                    
            end
        end
        
        class SoapStruct < Hash
            include SoapType
            
            def self.elements
                @elements
            end
            
            def self.types
                return @elements.values
            end
            
            def self.soap_class
                SOAP::SOAPStruct
            end
            
            def self.soap_factory
                Spider::Soap::GenericStructFactory.new(self.qname)
            end
            
            def self.soap_info
                {:elements => @elements}
            end
            
            attr_reader :content
            def initialize(content=nil)
                if (content.is_a?(Hash))
                    self.replace(content)
                else
                    self.class.elements.each do |key, type|
                        self[key] = content.send(key)
                    end
                end
                self.class.elements.each do |key, type|
                    if type < SoapType
                        self[key] = type.new(self[key]) if self[key] && !self[key].is_a?(type)
                    end
                end
            end
        end
        
        class SoapProxy
            
            def initialize(target, soap_methods)
                @target = target
                @soap_methods = soap_methods
                shadow = class <<self; self; end
                soap_methods.each do |name, params|
                    shadow.class_eval do
                        define_method(name) do |*args|
                            wrap_soap_method(name, *args)
                        end
                    end
                end
            end
            
            def wrap_soap_method(name, *args)
                return super unless @soap_methods[name]
                res = @target.send(name, *args)
                return nil unless @soap_methods[name][:return]
                if (@soap_methods[name][:return][:type] < SoapType && !res.is_a?(@soap_methods[name][:return][:type]))
                    return @soap_methods[name][:return][:type].new(res)
                else
                    return res
                end
            end
            
        end
        
        
    end
    
    
end