require 'spec_helper'
require 'spiderfw/controller/controller'

describe Spider::Controller, '.before, .before_unless' do

    before(:each) do
        Object.send(:remove_const, :C) if defined?(C)
        Object.send(:remove_const, :A) if defined?(A)
        class C < Spider::Controller
            attr_reader :ok
            
            def before_list(action='', *params)
                $ok = true
            end

            def list_stuff; end
            def method1; end
            def method2; end

        end
        class A < Spider::Controller
            route 'route_c', C
        end
        $ok = false
    end

    it "should call the before method matching a RegExp" do
        C.before(/^list_/, :before_list)
        a = A.new(Spider::Request.new({}), Spider::Response.new)
        a.do_dispatch(:before, 'route_c/list_stuff')
        $ok.should == true
    end

    it "should not call the before method if RegExp doesn't match" do
        C.before(/^something_else_/, :before_list)
        a = A.new(Spider::Request.new({}), Spider::Response.new)
        a.do_dispatch(:before, 'route_c/list_stuff')
        $ok.should == false 
    end

    it "should call the before method matching a Proc" do
        C.before(Proc.new{ |action| action.to_s =~ /list/ }, :before_list )
        a = A.new(Spider::Request.new({}), Spider::Response.new)
        a.do_dispatch(:before, 'route_c/list_stuff')
        $ok.should == true
    end

    it "should not call a before_unless method if RegExp matches" do
        C.before_unless(/^list_/, :before_list)
        a = A.new(Spider::Request.new({}), Spider::Response.new)
        a.do_dispatch(:before, 'route_c/list_stuff')
        $ok.should == false
    end

    it "should call a before_unless method if RegExp does not match" do
        C.before_unless(/^list_/, :before_list)
        a = A.new(Spider::Request.new({}), Spider::Response.new)
        a.do_dispatch(:before, 'route_c/method1')
        $ok.should == true
    end

end