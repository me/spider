require 'spec_helper'
require 'spiderfw/controller/controller'

describe Spider::Controller, '#route_path' do

    it "should return the full path, following a chain" do
        module App
            include Spider::App
            @route_path = "app"
            class A < Spider::Controller
            end
            class B < Spider::Controller
                route 'a_path', A
            end
            class C < Spider::Controller
                route 'b_path', B
            end
        end
        
        App::A.route_path.should == '/app/b_path/a_path'
    end

    it "should apply the http.proxy_mapping to paths" do
        Spider.conf.set('http.proxy_mapping', {
            '/proxyed' => ''
        })
        module App
            include Spider::App
            @route_path = "app"
            class A < Spider::Controller
            end
            class B < Spider::Controller
                route 'a_path', A
            end
            class C < Spider::Controller
                route 'b_path', B
            end
        end
        App::A.route_path.should == '/proxyed/app/b_path/a_path'
    end

end