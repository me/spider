require 'tmpdir'
require 'fileutils'
require 'spiderfw/test/page_object'


module Spider; module Test

    def self.setup_env
        @tmpdir = File.join(Dir.tmpdir, 'spider_test')
        FileUtils.rm_rf(@tmpdir) if File.exists?(@tmpdir)
        FileUtils.mkdir(@tmpdir)
        Spider.setup_paths(@tmpdir)
    end

    def self.teardown_env
        FileUtils.rm_rf(@tmpdir)
    end
    
    def self.env
        @env ||= {}
    end
    
    def self.before
        if Spider.init_done?
            Spider.config.get('storages').keys.each do |k|
                Spider::Model::BaseModel.get_storage(k).start_transaction
            end
            unless Spider.runmode == 'production'
                FileUtils.rm_rf(Spider.paths[:var]) 
                FileUtils.mkdir_p(Spider.paths[:var])
            end
        end
        begin
           Mail::TestMailer.deliveries.clear
        rescue
        end
        Spider::Request.reset_current
        Spider.apps.each do |name, mod|
            mod.before_test if mod.respond_to?(:before_test)
        end
    end
    
    def self.after
        if Spider.init_done?
            Spider.config.get('storages').keys.each do |k|
                storage = Spider::Model::BaseModel.get_storage(k)
                storage.rollback! if storage.supports_transactions?
            end
        end
        begin
           Mail::TestMailer.deliveries.clear
        rescue
        end
        Spider.apps.each do |name, mod|
            mod.after_test if mod.respond_to?(:after_test)
        end
    end
    
    def self.load_fixtures!(app)
        load_fixtures(app, true)
    end
    
    def self.load_fixtures(app, truncate=false)
        path = File.join(app.path, 'test', 'fixtures')
        loaded = []
        Dir.glob(File.join(path, '*.yml')).each do |yml|
            loaded += Spider::Model.load_fixtures(yml, truncate)
        end
    end
    
    def self.load_fixtures_file(app, file, truncate=false)
        path = File.join(app.path, 'test', 'fixtures')
        Spider::Model.load_fixtures(File.join(path, file)+'.yml', truncate)
    end
    
    def self.load_fixtures_file!(app, file)
        load_fixtures_file(app, file, true)
    end
    
    def self.restart_transactions
        Spider.config.get('storages').keys.each do |k|
            storage = Spider::Model::BaseModel.get_storage(k)
            storage.rollback!
            storage.start_transaction
        end
    end
    
    def self.use_storage_stub_for(app_or_model)
        require 'spiderfw/test/stubs/storage_stub'
        Spider::Test.env[:storage_stub] ||= StorageStub.new('dummy')
        models = []
        if app_or_model < Spider::App
            models = app_or_model.models
        else
            models = [app_or_model]
        end
        models.each do |m|
            m.use_storage 'stub:stub://stub'
        end
    end
    
    
end; end

require 'spiderfw/controller/controller'
require 'spiderfw/config/options/spider'
begin
    require 'ruby-debug'
    Debugger.start
rescue
end
require 'spiderfw/test/extensions/db_storage'
Spider::Test.setup_env