Feature: sending e-mail from controllers with MessengerHelper

  Scenario: immediate send
    Given I am in the MailTestController controller
    And the configuration setting "messenger.send_immediate" is "true"
    When I send the "simple" template from the controller
    Then the "simple" e-mail should be sent
    
  Scenario: queued send
    Given I am in the MailTestController controller
    And the configuration setting "messenger.send_immediate" is "false"
    When I send the "simple" template from the controller 
    Then the "simple" e-mail should be queued
    And no e-mail should be sent
    
  Scenario: erb templates
    Given I am in the MailTestController controller
    When I set the scene variable "test_var" to "test_value"
    And I send the "vars" template from the controller
    And I process the "e-mail" queue
    Then the "vars" e-mail should be sent
    And the sent e-mail text should contain "test_var = test_value"
    
  Scenario: html e-mail
    Given I am in the MailTestController controller
    When I send the "multipart" template from the controller
    And I process the "e-mail" queue
    Then the "multipart" e-mail should be sent
    And the sent e-mail should be multipart
    And the sent e-mail should have a text part
    And the sent e-mail should have an html part