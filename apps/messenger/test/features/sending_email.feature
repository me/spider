Feature: sending e-mail

  Scenario: add to queue
    When I send a test e-mail through Messenger
    Then the test e-mail should be added to the queue
    
  Scenario: process queue
    Given I sent a test e-mail through Messenger
    When I process the "e-mail" queue
    Then the test e-mail should be sent