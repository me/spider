Given /^I sent a test e-mail through Messenger$/ do
    When "I send a test e-mail through Messenger"
end

Given /^I am in the MailTestController controller$/ do
    require 'apps/messenger/test/lib/controllers/mail_test_controller'
    @controller = Spider::Messenger::MailTestController.new(Spider::Request.new({}), Spider::Response.new)
end

When /^I send a test e-mail through Messenger$/ do
    Spider::Messenger.email(TEST_EMAIL[:from], TEST_EMAIL[:to], "Subject: #{TEST_EMAIL[:subject]}", TEST_EMAIL[:body])
end

When /^I send the "(.+)" template from the controller$/ do |template|
    @controller.send(:set_action, 'test_send_email')
    @controller.before('test_send_email', template)
    @controller.execute('test_send_email', template)
    @controller.after('test_send_email', template)
end

When /^I add the following attachments to the controller:$/ do |attachments|
    if attachments.hashes.empty?
        @controller.attachments = attachments.raw.flatten
    else
        @controller.attachments = attachments.hashes
    end
end


When /^I set the scene variable "(.+)" to "(.+)"$/ do |var_name, var_value|
    @controller.scene << {var_name.to_sym => var_value}
end

Then /^the test e-mail should be added to the queue$/ do
    @queued = Spider::Messenger::Email.where(:sent => nil).order_by(:obj_created, :desc).limit(1).first
    @queued.should_not == nil
    @queued.from.should == TEST_EMAIL[:from]
    @queued.to.should == TEST_EMAIL[:to]
    @queued.body.should == TEST_EMAIL[:body]
    @queued.next_try.should_not == nil
    @queued.next_try.should <= DateTime.now
end

Then /^the test e-mail should be sent$/ do
    sent = Mail::TestMailer.deliveries.last
    sent.from.first.should == TEST_EMAIL[:from]
    sent.to.first.should == TEST_EMAIL[:to]
    sent.subject.should == TEST_EMAIL[:subject]
    sent.body.should == TEST_EMAIL[:body]    
end

Then /^the "(.+)" e-mail should be sent$/ do |template|
    sent = Mail::TestMailer.deliveries.last
    sent.from.first.should == TEST_EMAIL[:from]
    sent.to.first.should == TEST_EMAIL[:to]
    sent.subject.should == "Test - #{template} template"
    @sent_message = sent
end

Then /^no e-mail should be sent$/ do
    Mail::TestMailer.deliveries.length.should == 0
end

Then /^the "(.+)" e-mail should be queued$/ do |template|
    @queued = Spider::Messenger::Email.where(:sent => nil).order_by(:obj_created, :desc).limit(1).first
    @queued.should_not == nil
    @queued.from.should == TEST_EMAIL[:from]
    @queued.to.should == TEST_EMAIL[:to]
    @queued.headers.should =~ /Subject: Test - #{template} template/
end

Then /^the sent e-mail should be multipart$/ do
    @sent_message.multipart?.should == true
end

Then /^the sent e-mail should have a text part$/ do
    @sent_message.text_part.blank?.should_not == true
end

Then /^the sent e-mail should have an html part$/ do
    @sent_message.html_part.blank?.should_not == true
end

Then /^the sent e-mail text should contain "(.+)"$/ do |search|
    @sent_message.body.to_s.should =~ /#{Regexp.quote(search)}/
end

Then /^the sent e-mail should have "(\d+)" attachments?$/ do |n|
    @sent_message.attachments.length.should == n.to_i
end

Then /^the sent e-mail "(\d+)\w\w" attachment filename should be "(.+)"$/ do |n, name|
    @sent_message.attachments[n.to_i - 1].filename.should == name
end

Then /^the sent e-mail "(\d+)\w\w" attachment mime type should be "(.+)"$/ do |n, name|
    @sent_message.attachments[n.to_i - 1].mime_type.should == name
end