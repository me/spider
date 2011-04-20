require 'spiderfw/test/spec'

describe Spider::Model::Mapper do
    before(:all) do
        require 'test/apps/zoo/_init.rb'
        Spider::Test.use_storage_stub_for(Zoo)
    end

    describe "#save_all" do
        before(:each) do
            @family = Zoo::Family.new(:id => 'felines', :name => 'Felines')
            @animal = Zoo::Animal.new(:id => 'cat', :name => 'Cat', :family => @family)
        end

        it "releases the unit of work after saving" do
            @animal.mapper.save_all(@animal)
            Spider::Model.unit_of_work.should == nil
        end

    end
    
    describe "#find" do
        
        it "releases the identity mapper after loading" do
            Spider::Model.identity_mapper = nil
            q = Spider::Model::Query.new
            Zoo::Animal.mapper.find(q)
            Spider::Model.identity_mapper.should == nil
        end
        
    end

end