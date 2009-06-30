Spider.load_app('core/components')

module Spider

    module Admin
        @description = ""
        @version = 0.1
        @short_name = 'admin'
        @path = File.dirname(__FILE__)
        @controller = :AdminController
        include Spider::App

        @apps = {}
    end
    
end

require 'apps/core/admin/controllers/admin_controller'
require 'apps/core/admin/widgets/admin_menu/admin_menu'

Spider::Template.register_namespace('spider-admin', Spider::Admin)

Spider::Layout.register_layout(:spider_admin, '/core/admin/spider_admin.layout')
