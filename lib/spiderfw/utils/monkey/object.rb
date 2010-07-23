major, minor, patch = RUBY_VERSION.split('.').map{ |v| v.to_i }
if major <= 1 && minor <= 8

    class Object
        module InstanceExecHelper; end
        include InstanceExecHelper
        def instance_exec(*args, &block)
            begin
                old_critical, Thread.critical = Thread.critical, true
                n = 0
                n += 1 while respond_to?(mname="__instance_exec#{n}")
                InstanceExecHelper.module_eval{ define_method(mname, &block) }
            ensure
                Thread.critical = old_critical
            end
            begin
                ret = send(mname, *args)
            ensure
                InstanceExecHelper.module_eval{ remove_method(mname) } rescue nil
            end
            ret
        end
    end
    
end

class Object
    
    def blank?
        respond_to?(:empty?) ? empty? : !self
    end
    
end