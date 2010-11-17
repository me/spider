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
            Spider.logger.debug("Running job #{self.uuid}")
            t = self.task.untaint
            Thread.start{
                $SAFE = 3
                eval(t)
            }.join
        end
        
    end
    
end; end