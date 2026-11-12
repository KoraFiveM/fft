@kora @vending @ui
Feature: Vending machine purchases
  Scenario: Buy one soda
    Given I am at the configured soda vending machine
    And I have enough cash and inventory capacity for 1 "soda"
    When I select "Browse Vending Machine" on the machine
    And I buy 1 "soda" through the inventory UI
    Then my inventory should contain 1 more "soda"
    And my cash should have decreased by 5

  Scenario: Buy one water bottle
    Given I am at the configured soda vending machine
    And I have enough cash and inventory capacity for 1 "water_bottle"
    When I select "Browse Vending Machine" on the machine
    And I buy 1 "water_bottle" through the inventory UI
    Then my inventory should contain 1 more "water_bottle"
    And my cash should have decreased by 4
