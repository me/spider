require 'spiderfw/init'
require 'spiderfw/http/adapters/rack'
PhusionPassenger.on_event(:starting_worker_process) do
    Spider.start_loggers
    Spider.startup
end
rack_app = Spider::HTTP::RackApplication.new
app = proc do |env|
    rack_app.call(env)
end
run app
