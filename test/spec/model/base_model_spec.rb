require 'spiderfw/test/spec'

describe Spider::Model::BaseModel do
    before(:all) do
        require 'test/apps/zoo/_init.rb'
        Spider::Test.use_storage_stub_for(Zoo)
    end
    
    describe "#use_unit_of_work" do
        it "creates a new unit of work and mapper"
    end


end