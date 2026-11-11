@native
Feature: Native runtime
  Scenario: Player is available
    Given I am alive

  Scenario: Turning preserves position
    Given I am alive
    And I am on foot
    And I remember my position
    When I face heading 90
    Then my heading should be 90
    And I should be within 1 metres of my remembered position

  Scenario: Armour can be changed
    Given I am alive
    When I set my armour to 25
    Then my armour should be 25
    When I set my armour to 0
    Then my armour should be 0

  Scenario: Find a soda machine
    Given I am alive
    And I am on foot
    When I am at the configured soda vending machine
    Then a soda machine should be nearby

  Scenario: Player ped has a valid model
    Given I am alive
    Then my player model should be valid

  Scenario: Face north
    Given I am on foot
    When I face heading 0
    Then my heading should be 0

  Scenario: Face south
    Given I am on foot
    When I face heading 180
    Then my heading should be 180

  Scenario: Face west
    Given I am on foot
    When I face heading 270
    Then my heading should be 270

  Scenario: Full armour
    Given I am alive
    When I set my armour to 100
    Then my armour should be 100

  Scenario: Half armour
    Given I am alive
    When I set my armour to 50
    Then my armour should be 50

  Scenario: Restore full health
    Given I am alive
    When I set my health to maximum
    Then my health should be 0 below maximum

  Scenario: Health reduction
    Given I am alive
    When I set my health to maximum
    And I lower my health by 10
    Then my health should be 10 below maximum

  Scenario: Camera turns right
    Given I am alive
    When I turn my camera to 45 degrees
    Then my camera heading should be 45 degrees

  Scenario: Camera turns left
    Given I am alive
    When I turn my camera to -45 degrees
    Then my camera heading should be -45 degrees
