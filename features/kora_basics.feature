@kora @basics
Feature: Seeded Kora character
  Scenario: Seed balances are restored
    Given my test character should have seeded balances

  Scenario: Inventory starts empty
    Given my test character inventory should be empty

  Scenario: Soda fits in inventory
    Given my test character inventory should be empty
    Then I can carry 1 "soda"

  Scenario: Grant soda
    Given my test character inventory should be empty
    When I receive 2 "soda"
    Then I should have 2 "soda"

  Scenario: Remove granted soda
    Given my test character inventory should be empty
    When I receive 2 "soda"
    And I remove 1 "soda"
    Then I should have 1 "soda"

  Scenario: Grant water
    Given my test character inventory should be empty
    When I receive 3 "water_bottle"
    Then I should have 3 "water_bottle"

  Scenario: Change bank balance
    Given my test character should have seeded balances
    When I set my "bank" balance to 75
    Then my "bank" balance should be 75

  Scenario: Change cash balance
    Given my test character should have seeded balances
    When I set my "cash" balance to 80
    Then my "cash" balance should be 80
