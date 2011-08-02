module Spider
    
    module FirstResponder
        
        def before(action='', *arguments)
            # if Spider.conf.get('profiling.enable') && @request.env['QUERY_STRING'] =~ /profile=true/
            #     @profiling_started = Spider::Profiling.start
            # end
            catch :done do
                begin
                    super
                rescue => exc
                    self.done = true
                    try_rescue(exc)
                end
            end
        end
        
        def execute(action='', *arguments)
            catch :done do
                begin
                    super
                rescue => exc
                    self.done = true
                    try_rescue(exc)
                end
            end
        end
        
        def after(action='', *arguments)
            catch :done do
                begin
                    super
                rescue => exc
                    self.done = true
                    try_rescue(exc)
                end
            end
            # Spider::Profiling.stop if (@profiling_started)
            
        end
        
        def try_rescue(exc)
            super
            self.done = true
        end
        
        
    end
    
end