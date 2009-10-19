Spider::Worker.every('2m') do
    Spider::Messenger.process_queue(:email)
end