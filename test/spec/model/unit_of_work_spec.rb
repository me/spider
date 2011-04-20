require 'spiderfw/test/spec'

describe Spider::Model::UnitOfWork do

    describe "#add" do

        it "adds all children tree if called with :save action" do
            uow = Spider::Model::UnitOfWork.new
            uow.add(@cat, :save)
            uow.has?(@cat).should == true
            uow.has?(@dog).should == true
            uow.has?(@felines).should == true
            uow.has?(@canides).should == true
        end

        it "adds all elements in a QuerySet" do
            uow = Spider::Model::UnitOfWork.new
            uow.add(@animals)
            uow.has?(@cat).should == true
            uow.has?(@dog).should == true
            uow.has?(@parrot).should == true
        end

    end
    
    before(:all) do
        require 'test/apps/zoo/_init.rb'
        Spider::Test.use_storage_stub_for(Zoo)
    end

    before(:each) do
        @felines = Zoo::Family.new(:id => 'felines', :name => 'Felines')
        @canides = Zoo::Family.new(:id => 'canides', :name => 'Canides')
        @cat = Zoo::Animal.new(:id => 'cat', :name => 'Zoe', :family => @felines)
        @dog = Zoo::Animal.new(:id => 'dog', :name => 'Fido', :family => @canides)
        @parrot = Zoo::Animal.new(:id => 'parrot', :name => 'Coco')
        @cat.friends << @dog
        @animals = Spider::Model::QuerySet.static(Zoo::Animal)
        @animals << @cat
        @animals << @dog
        @animals << @parrot
    end

end