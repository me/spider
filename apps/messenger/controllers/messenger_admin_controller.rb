module Spider; module Messenger

    class AdminController < Spider::Admin::AppAdminController
        layout ['/core/admin/admin', 'admin/_admin'], :assets => 'messenger'

        Messenger.queues.keys.each do |queue|
            route queue.to_s, :queue, :do => lambda{ |action| @queue = action.to_sym }
        end

        def before(action='', *params)
            super
            @scene.queues = []
            @scene.queue_info = {}
            Messenger.queues.each do |name, details|
                next if  Spider.conf.get("messenger.#{name}.backends").empty?
                @scene.queues << name
                model = Spider::Messenger.const_get(details[:model])
                @scene.queue_info[name] = {
                    :label => details[:label]
                }
            end
        end

        __.html :template => 'admin/index'
        def index
            @scene.queues.each do |name|
                details = Spider::Messenger.queues[name]
                model = Spider::Messenger.const_get(details[:model])
                @scene.queue_info[name] = {
                    :sent => model.sent_messages.total_rows,
                    :queued => model.queued_messages.total_rows,
                    :failed => model.failed_messages.total_rows
                }
            end

        end

        __.html :template => 'admin/queue'
        def queue
            q = Messenger.queues[@queue]
            model = Spider::Messenger.const_get(q[:model])
            @scene.queue = @queue
            @scene.title = q[:label]
            @scene.admin_breadcrumb << {:label => @scene.title, :url => self.class.url(@queue)}
            @scene.queued = model.queued_messages
            @scene.sent = model.sent_messages
            @scene.failed = model.failed_messages
        end


    end

end; end