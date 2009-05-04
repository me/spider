Spider.load_apps 'zoo'
Spider.route_apps

def Spider.test_teardown
    Spider::Logger.debug("TEST TEARDOWN!!!!")
    File.unlink(Spider.paths[:root]+'/var/db.test.sqlite')
end

