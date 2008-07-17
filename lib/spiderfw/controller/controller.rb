module Spider
    
    class Controller
        include Dispatcher
        
        class << self
            #include Dispatcher
            before_filters, after_filters = [], []

        
            def before(filter, opts={}, &block)
                add_filter(before_filters, filter || block, opts)
            end
        
            def after(filter, opts={}, &block)
                add_filter(after_filters, filter || block, opts)
            end
        
            def add_filter(filters, filter, opts)
                filters << [filter, opts]
            end
        end
        
        attr_reader :status, :headers, :body
        attr_reader :action
        attr_accessor :_written
        
        def initialize(args={})
            @env = args[:env] || {}
            @status = 200
            @headers = {
                'Content-Type' => 'text/plain',
                'Connection' => 'close'
            }
            @stage = args[:stage] || Stage.new
            @parent = args[:parent] || nil
            @action = nil
        end
        
        def _call_filters(type, filters, action_name)
            (filters || []).each do |filter, rule|
                next if (rule.key?(:only) && !rule[:only].include?(action_name))
                next if (rule.key?(:exclude) && rule[:only].include?(action_name))
                case filter
                when Symbol, String
                    send(filter)
                when Proc
                    self.instance_eval(&filter)
                end
            end
            # Call before_action and similar if defined
            send("#{type}_#{action_name}") if respond_to?("#{type}_#{action_name}")
            return :filter_chain_completed
        end
        
        def execute_before
            p "Executing before"
        end
        
        def execute_after
            p "Executing after"
        end
        
        def execute_action(action_name)
            # p "SENDING #{action_name}"
            # p "I AM:"
            # p self
            send(action_name)
        end
        
        
        def handle(action=nil)
            action = (!action || action.to_s.strip.length == 0) ? :index : action
            @action = action
            # caught = catch do
            #     _call_filters('before', self.class.before_filters, action)
            # end
            #    
            # case caught 
            # when :filter_chain_completed
            #     _call_action(action)
            # end
            # 
            # _call_filters('after', self.class.after_filters, action)
            execute_action(action)
        end
        
        def render(view_name)
        end
        
    end
    
    
end