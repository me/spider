require 'cucumber/rspec/doubles'
require 'spiderfw/spider'
require 'spiderfw/test'

Before do
    Spider.config.get('storages').keys.each do |k|
        Spider::Model::BaseModel.get_storage(k).start_transaction
    end
    begin
       Mail::TestMailer.deliveries.clear
    rescue
    end
end

After do
    Spider.config.get('storages').keys.each do |k|
        Spider::Model::BaseModel.get_storage(k).rollback!
    end
    begin
       Mail::TestMailer.deliveries.clear
    rescue
    end
end