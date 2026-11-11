@kora @kora_consumables
Feature: kora_consumables eating and drinking
  Using a food or drink item shows a progress bar, then removes the item and
  changes hunger, thirst and stress. A use is started through
  exports.kora_core:useItem, the funnel the inventory calls when a player uses a
  slot; the inventory UI click itself is not driven. Needs values are asserted
  as a range because needs decay by one point a minute.

  The scenarios assume the default "apply effects when finished" setting
  (Config.applyStatusOn = 'complete'), which a step file cannot read.

  Not covered: cancelling a use (kora_lib's hook has no progress-cancel action),
  the too-fast-completion guard (needs a modified client), alcohol and smoking
  (they leave a 15 second screen and walk effect on the tester, and smoking
  writes health metadata), and accepted AddFood/AddDrink/AddAlcohol/AddCustom
  calls (they change the running config for every player until restart).

  Background:
    Given resource "kora_consumables" is running

  Scenario: Eating a sandwich restores hunger and uses the item
    Given my metadata "hunger" is 50
    And I hold 1 "sandwich"
    When I start consuming "sandwich"
    Then the consumable progress bar should read "Eating Sandwich"
    And my "sandwich" use should complete
    And my metadata "hunger" should be at least 69
    And my metadata "hunger" should be at most 70
    And I should have no "sandwich"

  Scenario: Drinking water restores thirst and uses the item
    Given my metadata "thirst" is 30
    And I hold 1 "water_bottle"
    When I start consuming "water_bottle"
    Then a progress bar labelled "Drinking" should start
    And my "water_bottle" use should complete
    And my metadata "thirst" should be at least 69
    And my metadata "thirst" should be at most 70
    And I should have no "water_bottle"

  Scenario: Soda restores thirst and lowers stress
    Given my metadata "thirst" is 40
    And my metadata "stress" is 20
    And I hold 1 "soda"
    When I start consuming "soda"
    Then a progress bar labelled "Drinking" should start
    And my "soda" use should complete
    And my metadata "thirst" should be at least 64
    And my metadata "thirst" should be at most 65
    And my metadata "stress" should be at most 17
    And I should have no "soda"

  Scenario: A chocolate bar restores hunger and lowers stress
    Given my metadata "hunger" is 40
    And my metadata "stress" is 20
    And I hold 1 "chocolate_bar"
    When I start consuming "chocolate_bar"
    Then a progress bar labelled "Eating" should start
    And my "chocolate_bar" use should complete
    And my metadata "hunger" should be at least 54
    And my metadata "hunger" should be at most 55
    And my metadata "stress" should be at most 15
    And I should have no "chocolate_bar"

  Scenario: Needs are capped at 100
    Given my metadata "thirst" is 90
    And I hold 1 "water_bottle"
    When I start consuming "water_bottle"
    Then my "water_bottle" use should complete
    And my metadata "thirst" should be at least 99
    And my metadata "thirst" should be at most 100

  Scenario: Nothing changes until the use finishes
    Given my metadata "hunger" is 50
    And I hold 1 "sandwich"
    When I start consuming "sandwich"
    Then the consumable progress bar should read "Eating Sandwich"
    And my metadata "hunger" should be at most 50
    And I should have 1 "sandwich"
    And my "sandwich" use should complete
    And the progress bar should finish
    And I should have no "sandwich"

  @rejection
  Scenario: A second use is refused while one is in progress
    Given my metadata "thirst" is 10
    And I hold 2 "water_bottle"
    When I start consuming "water_bottle"
    Then a progress bar labelled "Drinking" should start
    And consuming "water_bottle" now should be refused
    And my "water_bottle" use should complete
    And my metadata "thirst" should be at least 49
    And my metadata "thirst" should be at most 50
    And I should have 1 "water_bottle"

  @server @rejection
  Scenario: An item that is not held cannot be consumed
    Given my metadata "hunger" is 50
    Then I should have no "sandwich"
    And consuming "sandwich" now should be refused
    And my metadata "hunger" should be at most 50
    And my metadata "hunger" should be at least 49

  @server @rejection
  Scenario Outline: Legacy consumable registration refuses bad input
    Then registering "<item>" as legacy "<class>" worth <value> should be refused with "<reason>"

    Examples:
      | item             | class | value | reason              |
      | sandwich         | food  | 10    | already added       |
      | water_bottle     | drink | 10    | already added       |
      | fft_no_such_item | food  | 10    | item does not exist |
      | fft_no_such_item | drink | 101   | invalid arguments   |

  # ---------------------------------------------------------------------------
  # Every configured consumable (kora_consumables/shared/Config.lua) is a real
  # shared item whose use kora_consumables owns. The beer_pisswaser rows name the
  # real items (kora_core/shared/upstream/items.lua); Config.lua once listed them
  # misspelt as "beer_posswaser3/4", which left them without a use handler.
  @server
  Scenario Outline: A configured consumable is handled by kora_consumables
    Then kora_consumables should handle the use of "<item>"

    Examples: drinks
      | item         |
      | water        |
      | coffee       |
      | water_bottle |
      | soda         |

    Examples: food
      | item          |
      | sandwich      |
      | chips         |
      | egg_sandwich  |
      | hot_dog       |
      | bread         |
      | chocolate_bar |

    Examples: smokes
      | item              |
      | cigarette         |
      | joint             |
      | ak47_joint        |
      | amnesia_joint     |
      | blue_dream_joint  |
      | og_kush_joint     |
      | purple_haze_joint |
      | skunk_joint       |

    Examples: liquor
      | item            |
      | ambeer          |
      | beer            |
      | beer_dusche     |
      | beer_logger     |
      | beer_pisswaser  |
      | beer_pisswaser2 |
      | beer_pisswaser3 |
      | beer_pisswaser4 |
      | whiskey         |
      | vodka           |
      | wine            |

  # Food default is hunger +20 (shared/deafaults.lua); chocolate_bar sets 15.
  Scenario Outline: Each food restores its configured hunger
    Given my metadata "hunger" is 30
    And I hold 1 "<item>"
    And I watch the inventory use receipts
    When I start consuming "<item>"
    Then a progress bar labelled "Eating" should start
    And my "<item>" use should complete
    And my metadata "hunger" should be at least <low>
    And my metadata "hunger" should be at most <high>
    And I should have no "<item>"
    And the inventory should have recorded 1 use of "<item>"

    Examples:
      | item          | low | high |
      | sandwich      | 49  | 50   |
      | chips         | 49  | 50   |
      | egg_sandwich  | 49  | 50   |
      | hot_dog       | 49  | 50   |
      | bread         | 49  | 50   |
      | chocolate_bar | 44  | 45   |

  # Drink default is thirst +20; water_bottle sets 40 and soda 25.
  Scenario Outline: Each drink restores its configured thirst
    Given my metadata "thirst" is 30
    And I hold 1 "<item>"
    When I start consuming "<item>"
    Then a progress bar labelled "Drinking" should start
    And my "<item>" use should complete
    And my metadata "thirst" should be at least <low>
    And my metadata "thirst" should be at most <high>
    And I should have no "<item>"

    Examples:
      | item         | low | high |
      | water        | 49  | 50   |
      | coffee       | 49  | 50   |
      | water_bottle | 69  | 70   |
      | soda         | 54  | 55   |

  Scenario: Hunger already at 100 stays at 100
    Given my metadata "hunger" is 100
    And I hold 1 "sandwich"
    When I start consuming "sandwich"
    Then my "sandwich" use should complete
    And my metadata "hunger" should be at least 99
    And my metadata "hunger" should be at most 100
    And I should have no "sandwich"

  # incrementMetaData clamps to 0-100: stress 3 - 5 becomes 0.
  Scenario: Stress relief cannot take stress below zero
    Given my metadata "stress" is 3
    And I hold 1 "chocolate_bar"
    When I start consuming "chocolate_bar"
    Then my "chocolate_bar" use should complete
    And my metadata "stress" should be 0
    And I should have no "chocolate_bar"

  Scenario: Only one item of a stack is consumed
    Given my metadata "thirst" is 20
    And I hold 3 "water_bottle"
    When I start consuming "water_bottle"
    Then my "water_bottle" use should complete
    And I should have 2 "water_bottle"
    And my metadata "thirst" should be at least 59
    And my metadata "thirst" should be at most 60

  @slow
  Scenario: The same item can be used again once the first use finished
    Given my metadata "thirst" is 10
    And I hold 2 "water_bottle"
    And I watch the inventory use receipts
    When I start consuming "water_bottle"
    Then my "water_bottle" use should complete
    When I start consuming "water_bottle"
    Then my "water_bottle" use should complete
    And my metadata "thirst" should be at least 89
    And my metadata "thirst" should be at most 90
    And I should have no "water_bottle"
    And the inventory should have recorded 2 use of "water_bottle"

  # FINISH_TOLERANCE is 250 ms on a 4000 ms class duration (server/server.lua).
  Scenario: A use is not accepted before its progress duration has run
    Given my metadata "hunger" is 40
    And I hold 1 "sandwich"
    When I start consuming "sandwich"
    Then my "sandwich" use should complete
    And my "sandwich" use should have taken at least 3750 milliseconds
    And my metadata "hunger" should be at least 59

  @rejection
  Scenario: A different consumable is refused while one is in progress
    Given my metadata "hunger" is 40
    And my metadata "thirst" is 40
    And I hold 1 "sandwich"
    And I hold 1 "water_bottle"
    When I start consuming "sandwich"
    Then a progress bar labelled "Eating" should start
    And consuming "water_bottle" now should be refused
    And my "sandwich" use should complete
    And I should have 1 "water_bottle"
    And my metadata "thirst" should be at most 40
    And my metadata "hunger" should be at least 59

  @rejection
  Scenario: Losing the item during the use gives no effect
    Given my metadata "hunger" is 50
    And I hold 1 "sandwich"
    When I start consuming "sandwich"
    Then a progress bar labelled "Eating" should start
    When I lose every "sandwich" while it is being consumed
    Then my "sandwich" use should complete
    And my metadata "hunger" should be at most 50
    And my metadata "hunger" should be at least 49
    And I should have no "sandwich"

  Scenario: A multi-use item loses one use and is kept
    Given my metadata "thirst" is 30
    And I hold 1 "water_bottle" with 2 uses left
    When I start consuming "water_bottle"
    Then my "water_bottle" use should complete
    And I should have 1 "water_bottle"
    And my "water_bottle" should have 1 uses left
    And my metadata "thirst" should be at least 69

  Scenario: A multi-use item is removed with its last use
    Given my metadata "thirst" is 30
    And I hold 1 "water_bottle" with 1 uses left
    When I start consuming "water_bottle"
    Then my "water_bottle" use should complete
    And I should have no "water_bottle"
    And my metadata "thirst" should be at least 69

  # Order of checks in legacyAdd: name, already configured, value, item exists.
  @server @rejection
  Scenario Outline: Legacy consumable exports refuse bad input in order
    Then the legacy consumable export "<export>" should refuse "<item>" with a <value> value and say "<reason>"

    Examples:
      | export     | item             | value       | reason              |
      | AddFood    |                  | ten         | invalid arguments   |
      | AddFood    | sandwich         | negative    | already added       |
      | AddFood    | chocolate_bar    | ten         | already added       |
      | AddDrink   | fft_no_such_item | negative    | invalid arguments   |
      | AddDrink   | fft_no_such_item | over        | invalid arguments   |
      | AddDrink   | fft_no_such_item | nan         | invalid arguments   |
      | AddFood    | fft_no_such_item | text        | invalid arguments   |
      | AddFood    | fft_no_such_item | none        | invalid arguments   |
      | AddFood    | fft_no_such_item | zero        | item does not exist |
      | AddDrink   | fft_no_such_item | hundred     | item does not exist |
      | AddAlcohol | beer             | ten         | already added       |
      | AddAlcohol | fft_no_such_item | ten         | item does not exist |
      | AddAlcohol | fft_no_such_item | over        | invalid arguments   |
      | AddCustom  | cigarette        | empty_table | already added       |
      | AddCustom  | water_bottle     | none        | already added       |
      | AddCustom  | fft_no_such_item | text        | invalid arguments   |
      | AddCustom  | fft_no_such_item | none        | invalid arguments   |
      | AddCustom  | fft_no_such_item | empty_table | item does not exist |

  @server @rejection
  Scenario Outline: Legacy exports refuse a non-text item name
    Then the legacy consumable export "<export>" should refuse a numeric item name

    Examples:
      | export     |
      | AddFood    |
      | AddDrink   |
      | AddAlcohol |
      | AddCustom  |

  @server @rejection
  Scenario Outline: The qb-smallresources identity reaches the same refusals
    Then the qb-smallresources export "<export>" should refuse "<item>" with a <value> value and say "<reason>"

    Examples:
      | export    | item             | value | reason              |
      | AddFood   | sandwich         | ten   | already added       |
      | AddDrink  | fft_no_such_item | ten   | item does not exist |
      | AddCustom | fft_no_such_item | text  | invalid arguments   |
