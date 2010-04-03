Spider::Worker.every("#{Spider.conf.get('messenger.queue.run_every')}s") do
    Spider::Messenger.process_queues
end