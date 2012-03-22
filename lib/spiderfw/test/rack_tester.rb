require 'rack/test'

class RackTester
    include Rack::Test::Methods

    def app
        Spider::HTTP::RackApplication.new
    end

end