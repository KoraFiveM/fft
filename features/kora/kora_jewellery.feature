@kora @kora_jewellery
Feature: kora_jewellery Vangelico display cases
  Twenty display cases can be smashed with a strong enough weapon while two
  police are on duty. Coordinates are case 1 of Config.Locations in
  shared/config.lua (its `offset` is where the player stands) and are unverified
  until run live. A successful smash is not covered: it needs two real officers
  on duty, sends them a dispatch call and locks the store until the reset timer.

  Background:
    Given resource "kora_jewellery" is running

  @server
  Scenario: Store publishes its display cases
    Then the jewellery store should publish 20 display cases

  @world
  Scenario: Free display case offers the smash option
    Given jewellery display case 1 should be untouched
    And I stand at -626.48 -235.77 38.06 facing 44.17
    When I aim at -626.83 -235.35 38.05
    Then the target option "Smash the display case1" should be visible

  @world @rejection
  Scenario: Smashing with bare hands is refused
    Given jewellery display case 1 should be untouched
    And I remember the jewellery alarm state
    And I remember my jewellery loot
    And I stand at -626.48 -235.77 38.06 facing 44.17
    And I hold no weapon at the jewellery store
    When I aim at -626.83 -235.35 38.05
    And I target "Smash the display case1"
    Then I should see a notification containing "Your weapon is not strong enough.."
    And no progress bar should be running
    And jewellery display case 1 should be untouched
    And the jewellery alarm state should be unchanged
    And I should have gained no jewellery loot

  @world @rejection
  Scenario: Reward cannot be claimed for a case that was never smashed
    Given jewellery display case 1 should be untouched
    And I remember my jewellery loot
    And I stand at -626.48 -235.77 38.06 facing 44.17
    When I claim the jewellery reward for display case 1 without smashing it
    Then I should have gained no jewellery loot
    And jewellery display case 1 should be untouched

  @world @rejection
  Scenario: Reward claim for an unknown case is ignored
    Given I remember my jewellery loot
    And I stand at -626.48 -235.77 38.06 facing 44.17
    When I claim the jewellery reward for display case 99 without smashing it
    Then I should have gained no jewellery loot
    And the jewellery store should publish 20 display cases

  @world @rejection
  Scenario: Case cannot be reserved without enough police
    Given fewer police are on duty than the jewellery store needs
    And jewellery display case 1 should be untouched
    And I stand at -626.48 -235.77 38.06 facing 44.17
    When I try to reserve jewellery display case 1 without enough police
    Then jewellery display case 1 should be untouched

  # Config.Locations rows (shared/config.lua): case coords and the offset where
  # the smash animation places the player.
  @world
  Scenario Outline: Display case <case> offers the smash option from its stand point
    Given jewellery display case <case> should be untouched
    And jewellery display case <case> should be published at <x> <y> <z> with its stand point at <ox> <oy> <oz> facing <h>
    And I stand at <ox> <oy> <oz> facing <h>
    When I aim at <x> <y> <z>
    Then the target option "Smash the display case<case>" should be visible

    Examples:
      | case | x       | y       | z     | ox      | oy      | oz    | h      |
      | 1    | -626.83 | -235.35 | 38.05 | -626.48 | -235.77 | 38.06 | 44.17  |
      | 2    | -625.81 | -234.7  | 38.05 | -625.57 | -234.98 | 38.06 | 44.23  |
      | 3    | -626.95 | -233.14 | 38.05 | -627.17 | -232.78 | 38.06 | 198.12 |
      | 4    | -628.0  | -233.86 | 38.05 | -628.3  | -233.53 | 38.06 | 218.03 |
      | 5    | -625.7  | -237.8  | 38.05 | -625.96 | -237.45 | 38.06 | 218.71 |
      | 6    | -626.7  | -238.58 | 38.05 | -626.98 | -238.23 | 38.06 | 222.45 |
      | 7    | -624.55 | -231.06 | 38.05 | -624.82 | -231.35 | 38.06 | 317.64 |
      | 8    | -623.13 | -232.94 | 38.05 | -623.61 | -233.27 | 38.06 | 306.75 |
      | 9    | -620.29 | -234.44 | 38.05 | -620.53 | -234.11 | 38.06 | 219.01 |
      | 10   | -619.15 | -233.66 | 38.05 | -619.42 | -233.23 | 38.06 | 219.28 |
      | 11   | -620.19 | -233.44 | 38.05 | -619.95 | -233.89 | 38.06 | 34.35  |
      | 12   | -617.63 | -230.58 | 38.05 | -617.96 | -230.87 | 38.06 | 308.28 |
      | 13   | -618.33 | -229.55 | 38.05 | -618.74 | -229.91 | 38.06 | 314.25 |
      | 14   | -619.7  | -230.33 | 38.05 | -619.36 | -230.05 | 38.06 | 135.08 |
      | 15   | -620.95 | -228.6  | 38.05 | -620.56 | -228.33 | 38.06 | 129.03 |
      | 16   | -619.79 | -227.6  | 38.05 | -620.15 | -227.88 | 38.06 | 317.69 |
      | 17   | -620.42 | -226.6  | 38.05 | -620.83 | -226.91 | 38.06 | 310.96 |
      | 18   | -623.94 | -227.18 | 38.05 | -623.76 | -227.49 | 38.06 | 42.71  |
      | 19   | -624.91 | -227.87 | 38.05 | -624.78 | -228.26 | 38.06 | 26.27  |
      | 20   | -623.84 | -228.47 | 38.05 | -624.15 | -227.77 | 38.06 | 213.51 |

  @world @rejection
  Scenario Outline: Bare hands are refused at display case <case> too
    Given jewellery display case <case> should be untouched
    And I remember the jewellery alarm state
    And I remember my jewellery loot
    And I stand at <ox> <oy> <oz> facing <h>
    And I hold no weapon at the jewellery store
    When I aim at <x> <y> <z>
    And I target "Smash the display case<case>"
    Then I should see a notification containing "Your weapon is not strong enough.."
    And no progress bar should be running
    And jewellery display case <case> should be untouched
    And the jewellery alarm state should be unchanged
    And I should have gained no jewellery loot

    Examples:
      | case | x       | y       | z     | ox      | oy      | oz    | h      |
      | 5    | -625.7  | -237.8  | 38.05 | -625.96 | -237.45 | 38.06 | 218.71 |
      | 12   | -617.63 | -230.58 | 38.05 | -617.96 | -230.87 | 38.06 | 308.28 |
      | 20   | -623.84 | -228.47 | 38.05 | -624.15 | -227.77 | 38.06 | 213.51 |

  # server/server.lua startSmash: the real claim callback, asked directly.
  @world @rejection
  Scenario: The smash claim reports how many police are missing
    Given fewer police are on duty than the jewellery store needs
    And jewellery display case 1 should be untouched
    And I stand at -626.48 -235.77 38.06 facing 44.17
    When I ask the jewellery store to start smashing display case 1
    Then the jewellery store should refuse the smash for too few police
    And jewellery display case 1 should be untouched

  @world @rejection
  Scenario Outline: The smash claim for an unknown display case <case> is refused silently
    Given I remember the jewellery display cases
    And I stand at -626.48 -235.77 38.06 facing 44.17
    When I ask the jewellery store to start smashing display case <case>
    Then the jewellery store should refuse the smash without a reason
    And the jewellery display cases should be unchanged

    Examples:
      | case |
      | 0    |
      | -1   |
      | 21   |
      | 99   |

  # Case 17 is about 11 m from case 1's stand point; the server allows 5 m.
  @world @rejection
  Scenario: The smash claim for a display case across the store is refused
    Given jewellery display case 17 should be untouched
    And I stand at -626.48 -235.77 38.06 facing 44.17
    When I ask the jewellery store to start smashing display case 17
    Then the jewellery store should refuse the smash without a reason
    And jewellery display case 17 should be untouched

  @world @rejection
  Scenario: A display case across the store cannot be reserved
    Given jewellery display case 17 should be untouched
    And I stand at -626.48 -235.77 38.06 facing 44.17
    When I try to reserve jewellery display case 17 without enough police
    Then jewellery display case 17 should be untouched

  @world @rejection
  Scenario Outline: Reserving unknown display case <case> changes nothing
    Given I remember the jewellery display cases
    And I stand at -626.48 -235.77 38.06 facing 44.17
    When I try to reserve jewellery display case <case> without enough police
    Then the jewellery display cases should be unchanged
    And the jewellery store should publish 20 display cases

    Examples:
      | case |
      | 0    |
      | -1   |
      | 21   |
      | 99   |

  @world @rejection
  Scenario: A display case addressed by a text key cannot be reserved
    Given I remember the jewellery display cases
    And jewellery display case 1 should be untouched
    And I stand at -626.48 -235.77 38.06 facing 44.17
    When I try to reserve the jewellery display case keyed "1"
    Then the jewellery display cases should be unchanged

  @world @rejection
  Scenario: A reservation flag that is not a boolean is refused
    Given jewellery display case 1 should be untouched
    And I stand at -626.48 -235.77 38.06 facing 44.17
    When I send jewellery display case 1 the reservation flag "true"
    Then jewellery display case 1 should be untouched

  @world @rejection
  Scenario: A case cannot be released by a player who never reserved it
    Given jewellery display case 1 should be untouched
    And I stand at -626.48 -235.77 38.06 facing 44.17
    When I release jewellery display case 1 without having reserved it
    Then jewellery display case 1 should be untouched
    And the jewellery store should publish 20 display cases

  @world @rejection
  Scenario Outline: Reward claims for invalid display case <case> pay nothing
    Given I remember the jewellery display cases
    And I remember my jewellery loot
    And I stand at -626.48 -235.77 38.06 facing 44.17
    When I claim the jewellery reward for display case <case> without smashing it
    Then I should have gained no jewellery loot
    And the jewellery display cases should be unchanged

    Examples:
      | case |
      | 0    |
      | -1   |
      | 21   |

  @world @rejection
  Scenario: Reward claim for a display case across the store pays nothing
    Given jewellery display case 17 should be untouched
    And I remember my jewellery loot
    And I stand at -626.48 -235.77 38.06 facing 44.17
    When I claim the jewellery reward for display case 17 without smashing it
    Then I should have gained no jewellery loot
    And jewellery display case 17 should be untouched

  @world @rejection
  Scenario: Replayed reward claims for an unsmashed case pay nothing
    Given jewellery display case 1 should be untouched
    And I remember my jewellery loot
    And I stand at -626.48 -235.77 38.06 facing 44.17
    When I claim the jewellery reward for display case 1 10 times without smashing it
    Then I should have gained no jewellery loot
    And jewellery display case 1 should be untouched

  # Needs fewer than Config.RequiredCops on duty, so no dispatch call can be raised.
  @world @rejection
  Scenario: The alarm does not trip without enough police
    Given fewer police are on duty than the jewellery store needs
    And I remember the jewellery alarm state
    And I stand at -626.48 -235.77 38.06 facing 44.17
    When I raise the jewellery alarm from display case 1
    Then the jewellery alarm state should be unchanged
    And jewellery display case 1 should be untouched

  @world @rejection
  Scenario Outline: The alarm cannot be tripped from <where>
    Given I remember the jewellery display cases
    And I remember the jewellery alarm state
    And I stand at -626.48 -235.77 38.06 facing 44.17
    When I raise the jewellery alarm from display case <case>
    Then the jewellery alarm state should be unchanged
    And the jewellery display cases should be unchanged

    Examples:
      | where                       | case |
      | an unknown display case     | 99   |
      | a display case 11 m away    | 17   |
