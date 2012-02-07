require 'spiderfw/init'
require 'spiderfw/http/adapters/rack'
if defined?(PhusionPassenger)
    PhusionPassenger.on_event(:starting_worker_process) do
        Spider.startup
    end
end
run Spider::HTTP::RackApplication.new
