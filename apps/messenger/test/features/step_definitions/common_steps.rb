Given /the configuration setting "([^"]+)" is "([^"]+)"/ do |setting, val|
    val = false if val == "false"
    val = true if val == "true"
    Spider.conf.set(setting, val)
end

When /^I process the "(\S+)" queue$/ do |queue|
    queue.gsub!(/\W+/, '')
    Spider::Messenger.process_queue(queue.to_sym)
end

