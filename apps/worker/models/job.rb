module Spider; module Worker
    
    class Job < Spider::Model::Managed
        element :uuid, UUID
        element :description, String
        element :time, DateTime
        element :task, String
        element :status, {
            'done' => 'Done', 'failed' => 'Failed'
        }
        
        def run
            t = self.task.untaint
            $SAFE = 4
            eval(t)
        end
        
    end
    
end; end