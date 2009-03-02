module Spider
    
    module FirstResponder
        
        def before(action='', *arguments)
            catch :done do
                begin
                    super
                rescue => exc
                    try_rescue(exc)
                end
            end
        end
        
        def execute(action='', *arguments)
            catch :done do
                begin
                    super
                rescue => exc
                    try_rescue(exc)
                end
            end
        end
        
        def after(action='', *arguments)
            catch :done do
                begin
                    super
                rescue => exc
                    try_rescue(exc)
                end
            end
        end
        
    end
    
end