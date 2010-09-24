require 'rubygems'
require 'ohai'
require 'httpclient'
$SPIDER_SERVANT_LIB = File.dirname(__FILE__)
require "#{$SPIDER_SERVANT_LIB}/resource"
require "#{$SPIDER_SERVANT_LIB}/resources/db"
require "#{$SPIDER_SERVANT_LIB}/resources/db/mysql"

module Spider
    
    module Servant
        
        class Servant
            DEFAULTS = {
                :config_file => '/etc/spider/servant.yml'
            }
        
            def initialize(config_file=nil)
                @config = {
                    :server_url => 'http://localhost:8989/spider/master'
                }
                config_file ||= Servant::DEFAULTS[:config_file] if File.exists?(Servant::DEFAULTS[:config_file])
                if config_file
                    y = YAML::load_file(config_file)
                    @config.merge!(y)
                end
                ohai = Ohai::System.new
                ohai.all_plugins
                @ohai = ohai
                @config[:servant_id] ||= ohai["hostname"]
                @config[:servant_name] ||= @config[:servant_id]
                create_resources
            end
        
            def ping_server(url=nil)
                url ||= @config[:server_url]
                @system_status = @ohai.to_json
                clnt = HTTPClient.new
                res = clnt.post("#{url}/ping", Spider::HTTP.params_to_hash(self.description))
                JSON.parse(res)
                if res[:commands]
                    res[:commands].each do |command|
                        command_result = execute_command(command[:name], command[:arguments])
                        clnt.post()
                    end
                end
            end
        
            def create_resources
                @resources = {}
                return unless @config['resources'].is_a?(Hash)
                @config['resources'].each do |res_type, hash|
                    @resources[res_type] ||= {}
                    case res_type
                    when 'db'
                        hash.each do |res_name, params|
                            @resources[res_type][res_name] = Resources::Db.get_resource(params['url'])
                        end
                    end
                end
            end
            
            def description
                {
                    :servant_id => @config[:servant_id],
                    :servant_name => @config[:servant_name],
                    :system_status => @system_status,
                    :resources => resources_description
                }
            end
            
            def resources_description
                desc = {}
                @resources.each do |type, type_resources|
                    desc[type] ||= {}
                    type_resources.each do |name, resource|
                        desc[type][name] = {
                            :description => resource.description.to_json
                        }
                    end
                end
            end
            
        end
        
    end
    
end