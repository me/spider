Feature: attachments from messenger helper

  Scenario: basic attachment
    Given I am in the MailTestController controller
    When I add the following attachments to the controller:
      | test_file1.txt |
    And I send the "simple" template from the controller 
    And I process the "e-mail" queue
    Then the "simple" e-mail should be sent
    And the sent e-mail should have "1" attachment
    And the sent e-mail "1st" attachment filename should be "test_file1.txt"
    And the sent e-mail "1st" attachment mime type should be "text/plain"
    
  Scenario: overriding attachment properties
    Given I am in the MailTestController controller
    When I add the following attachments to the controller:
      | path           | mime_type | filename |
      | test_file1.txt | image/jpg | file.png |
    And I send the "simple" template from the controller 
    And I process the "e-mail" queue
    Then the "simple" e-mail should be sent
    And the sent e-mail should have "1" attachment
    And the sent e-mail "1st" attachment filename should be "file.png"
    And the sent e-mail "1st" attachment mime type should be "image/jpg"
  
  