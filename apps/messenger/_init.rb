Spider.load_app('core/admin')
Spider.load_app('worker')

module Spider

    module Messenger

        @description = ""
        @version = 0.1
        @path = File.dirname(__FILE__)
        @controller = :MessengerController
        include Spider::App

    end
    
    Spider::Admin.add(Messenger)
    
end

require 'apps/messenger/messenger'
require 'apps/messenger/controllers/messenger_controller'
require 'apps/messenger/controllers/mixins/messenger_helper'

available_backends = {}
base = File.join(Spider::Messenger.path, 'backends')
Dir.new(base).each do |type|
    next if type[0].chr == '.'
    type_dir = File.join(base, type)
    next unless File.directory?(type_dir)
    available_backends[type.to_sym] = []
    Dir.new(type_dir).each do |bcknd|
        next if bcknd[0].chr == '.'
        name = File.basename(bcknd, '.rb')
        available_backends[type.to_sym] << name
    end
end
available_backends.each do |type, backends|
    Spider.config_option("messenger.#{type}.backends")[:params][:choices] = backends
    Spider.config_option("messenger.#{type}.backend")[:params][:choices] = backends
end


Spider.conf.get('messenger.email.backends').each do |backend|
    require File.join('apps/messenger/backends/email/', backend)
end
Spider.conf.get('messenger.sms.backends').each do |backend|
    require File.join('apps/messenger/backends/sms/', backend)
end