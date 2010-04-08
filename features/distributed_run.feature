Feature: Distributed runs

  In order to write software quicker
  As a software engineer
  I want to run my Cucumber features distributed across hardware
  
  Scenario: Distribute runs (localhost)
    Given Testjour is configured to run on localhost in a temp1 directory
    And Testjour is configured to run on localhost in a temp2 directory
    When I run `testjour sleep1.feature sleep2.feature`
    Then it should fail with "2 steps passed"
    And the output should contain "FAIL"
    And the output should contain "1 steps failed"
    And it should run on 2 remote slaves
    
  Scenario: Distribute runs (using named host)
    Given Testjour is configured to run on this machine in a temp1 directory
    And Testjour is configured to run on this machine in a temp2 directory
    When I run `testjour sleep1.feature sleep2.feature`
    Then it should fail with "2 steps passed"
    And the output should contain "FAIL"
    And the output should contain "1 steps failed"
    And it should run on 2 remote slaves
    
  Scenario: Distribute runs (using > 1 remote slave, queue host and rsync uri)
    Given Testjour is configured to run on this machine in a temp1 directory with 2 slaves
    And Testjour is configured to use this machine as the queue host
    And Testjour is configured to use this machine as the rsync host
    When I run `testjour sleep1.feature sleep2.feature`
    Then it should fail with "2 steps passed"
    And the output should contain "FAIL"
    And the output should contain "1 steps failed"
    And it should run on 2 remote slaves
  