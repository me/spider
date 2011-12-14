require 'spiderfw/init'
require 'apps/drb_server/lib/model_server'

unless ARGV.length == 2
    puts "Usage: ruby start_server.rb type druby://bind_address:port"
    exit
end

server_type = ARGV.shift
uri = ARGV.shift

case server_type
when 'model'
    server = SpiderApps::DrbServer::ModelServer.new(uri)
    server.start
else
    puts "Unrecognized server #{type}"
    exit
end