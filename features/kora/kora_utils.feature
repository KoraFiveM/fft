@kora @kora_utils
Feature: kora_utils small player utilities
  kora_utils bundles the seatbelt and race harness, the vehicle and weapon
  blacklist, hold-to-prone, wanted-level suppression, the qb-smallresources
  control and HUD compatibility exports, and the server's timed jobs. These
  scenarios drive the resource's own commands and key-mapping commands and
  read the result through its exports, natives and the inventory.

  Buckling plays the resource's own buckle sound to players within 5 metres
  of the tester.

  Not covered: crash ejection and harness wear (need a real collision), the
  short crouch tap (its stance has no readable export), health regeneration,
  the idle camera, the weapon wheel and world depopulation (frame or timer
  driven with no readable result), stripping a blacklisted weapon (would need
  a weapon given to the tester outside gameplay), the DecorSet compatibility
  export (it has no getter), harness use through the inventory item and the
  harness rate limit.

  Background:
    Given resource "kora_utils" is running

  Scenario: Seatbelt buckles and unbuckles in a car
    Given I am driving a temporary "sultan"
    When I buckle my seatbelt
    Then my seatbelt should be on
    When I press the seatbelt key
    Then my seatbelt should be off

  @rejection
  Scenario: Seatbelt is refused on a motorcycle
    Given I am driving a temporary "bati"
    And I wait 1000 milliseconds
    When I press the seatbelt key
    Then my seatbelt should be off

  @rejection
  Scenario: Seatbelt is refused on foot
    When I press the seatbelt key
    Then my seatbelt should be off

  @rejection
  Scenario: Race harness needs a harness item
    Given I should have no "harness"
    And I am driving a temporary "sultan"
    And I wait 2000 milliseconds
    When I run the command "raceharness"
    Then I should see a notification containing "You do not have a race harness to use"
    And my race harness should not be attached

  # Config.seatbelt.equipDuration = 5000 for both attaching and removing;
  # Config.HarnessUses = 20, and attaching spends one use.
  @slow
  Scenario: Race harness attaches, spends a use and comes off again
    Given I should have no "harness"
    And I hold 1 "harness"
    And I am driving a temporary "sultan"
    And I wait 2000 milliseconds
    When I run the command "raceharness"
    Then a progress bar labelled "Attaching Race Harness" should start
    And the progress bar should finish
    And my race harness should be attached
    And my race harness item should have 19 uses left
    When I run the command "raceharness"
    Then a progress bar labelled "Removing Race Harness" should start
    And the progress bar should finish
    And my race harness should not be attached
    And my race harness item should have 19 uses left

  @rejection
  Scenario: A blacklisted vehicle cannot be spawned
    When I try to spawn the blacklisted vehicle "oppressor"
    Then I should see a notification containing "That vehicle is not allowed on this server."
    And the blacklisted vehicle should not exist

  Scenario: Holding the stance key goes prone and a tap stands up
    When I hold the stance key long enough to go prone
    Then I should be lying prone
    When I tap the stance key
    Then I should not be lying prone

  @rejection
  Scenario: Prone is refused inside a vehicle
    Given I am driving a temporary "sultan"
    When I hold the stance key long enough to go prone
    Then I should not be lying prone
    And I should be in a vehicle

  Scenario: Wanted level is suppressed
    Then my maximum wanted level should be 0

  # Control 243 is INPUT_ENTER_CHEAT_CODE, unused by gameplay scripts.
  Scenario: A disabled control is enforced until it is removed
    When I add the control 243 to the disabled controls
    Then the control 243 should be disabled every frame
    When I remove the control 243 from the disabled controls
    Then invalid entries should not reach the disabled controls

  # HUD component 8 is the vehicle class label.
  Scenario: A hidden HUD component is listed until it is removed
    When I add the HUD component 8 to the hidden HUD components
    And I remove the HUD component 8 from the hidden HUD components
    Then invalid entries should not reach the hidden HUD components

  @rejection
  Scenario: Ammo display setting ignores non-boolean values
    Then a non-boolean ammo display setting should be ignored

  @server
  Scenario: A timed job runs when forced and not after it is stopped
    Given I schedule a timed job that is not due soon
    When I force the timed job to run
    Then the timed job should have run 1 time with the current clock
    When I stop the timed job
    And I force the timed job to run
    Then the timed job should have run 1 time with the current clock

  @server @rejection
  Scenario: A timed job with invalid arguments is not scheduled
    Then scheduling a timed job with invalid arguments should return nothing

  # ---------------------------------------------------------------------------
  # Seatbelt
  # ---------------------------------------------------------------------------

  Scenario: The seatbelt toggle event buckles and unbuckles like the key
    Given I am driving a temporary "sultan"
    When I buckle my seatbelt through the kora_utils toggle event
    Then my seatbelt should be on
    When I toggle my seatbelt through the kora_utils toggle event
    Then my seatbelt should be off

  Scenario: The seatbelt state bag follows the seatbelt
    Given I am driving a temporary "sultan"
    Then my seatbelt state should read "false"
    When I buckle my seatbelt
    Then my seatbelt state should read "true"
    When I press the seatbelt key
    Then my seatbelt state should read "false"

  Scenario: A buckled seatbelt blocks the vehicle exit control
    Given I am driving a temporary "sultan"
    And the vehicle exit control should be usable
    When I buckle my seatbelt
    Then the vehicle exit control should be blocked
    When I press the seatbelt key
    Then the vehicle exit control should be usable

  Scenario: Leaving the vehicle unbuckles the seatbelt
    Given I am driving a temporary "sultan"
    And I buckle my seatbelt
    When I leave my temporary vehicle
    Then my seatbelt should be off
    And my seatbelt state should read "false"

  @rejection
  Scenario: Seatbelt is refused on a bicycle
    Given I am driving a temporary "bmx"
    And I wait 1000 milliseconds
    When I press the seatbelt key
    Then my seatbelt should be off

  Scenario: The qb-smallresources seatbelt exports mirror kora_utils
    Given I am driving a temporary "sultan"
    Then the qb-smallresources seatbelt and harness exports should match kora_utils
    When I buckle my seatbelt
    Then the qb-smallresources seatbelt and harness exports should match kora_utils

  # ---------------------------------------------------------------------------
  # Race harness (Config.HarnessUses = 20, Config.seatbelt.equipDuration = 5000,
  # harness.separateFromSeatbelt = true)
  # ---------------------------------------------------------------------------

  @slow
  Scenario: Pressing the harness command again while attaching spends only one use
    Given I hold a race harness with 20 uses
    And I am driving a temporary "sultan"
    And I wait 2000 milliseconds
    When I run the command "raceharness"
    Then a progress bar labelled "Attaching Race Harness" should start
    When I run the command "raceharness"
    Then the progress bar should finish
    And my race harness should be attached
    And my harness state should read "true"
    And my race harness item should have 19 uses left
    And my seatbelt should be off
    And the qb-smallresources seatbelt and harness exports should match kora_utils

  @slow
  Scenario: Attaching a harness on its last use uses the item up
    Given I hold a race harness with 1 uses
    And I am driving a temporary "sultan"
    And I wait 2000 milliseconds
    When I run the command "raceharness"
    Then a progress bar labelled "Attaching Race Harness" should start
    And the progress bar should finish
    And my race harness should be attached
    And I should have no "harness"

  @rejection
  Scenario Outline: A harness with an invalid use count is treated as missing
    Given I hold a race harness with <uses> uses
    And I am driving a temporary "sultan"
    And I wait 2000 milliseconds
    When I run the command "raceharness"
    Then I should see a notification containing "You do not have a race harness to use"
    And no progress bar should be running
    And my race harness should not be attached
    And my race harness item should have <uses> uses left

    Examples:
      | uses |
      | 0    |
      | 21   |
      | -1   |

  @rejection
  Scenario: The harness command does nothing on foot
    Given I hold a race harness with 20 uses
    When I run the command "raceharness"
    And I wait 1500 milliseconds
    Then no progress bar should be running
    And my race harness should not be attached
    And I should not see a notification containing "You do not have a race harness to use"
    And my race harness item should have 20 uses left

  @rejection
  Scenario: The harness command does nothing on a bicycle
    Given I hold a race harness with 20 uses
    And I am driving a temporary "bmx"
    And I wait 2000 milliseconds
    When I run the command "raceharness"
    And I wait 1500 milliseconds
    Then no progress bar should be running
    And my race harness should not be attached
    And my race harness item should have 20 uses left

  @slow @rejection
  Scenario: Leaving the car while the harness is attaching spends no use
    Given I hold a race harness with 20 uses
    And I am driving a temporary "sultan"
    And I wait 2000 milliseconds
    When I run the command "raceharness"
    Then a progress bar labelled "Attaching Race Harness" should start
    When I leave my temporary vehicle
    Then the progress bar should finish
    And my race harness should not be attached
    And my race harness item should have 20 uses left

  @slow
  Scenario: Leaving the car takes the harness off
    Given I hold a race harness with 20 uses
    And I am driving a temporary "sultan"
    And I wait 2000 milliseconds
    When I run the command "raceharness"
    Then a progress bar labelled "Attaching Race Harness" should start
    And the progress bar should finish
    And my race harness should be attached
    When I leave my temporary vehicle
    Then my race harness should not be attached
    And my harness state should read "false"
    And my race harness item should have 19 uses left

  # ---------------------------------------------------------------------------
  # Vehicle blacklist (every other Config.blacklist.vehicles entry)
  # ---------------------------------------------------------------------------

  @rejection
  Scenario Outline: Every blacklisted vehicle model is refused
    When I try to spawn the blacklisted vehicle "<model>"
    Then I should see a notification containing "That vehicle is not allowed on this server."
    And the blacklisted vehicle should not exist

    Examples:
      | model      |
      | rhino      |
      | lazer      |
      | hydra      |
      | savage     |
      | buzzard    |
      | oppressor2 |
      | scramjet   |
      | deluxo     |
      | insurgent  |
      | blimp      |
      | blimp2     |
      | blimp3     |

  # ---------------------------------------------------------------------------
  # Control and HUD lists
  # ---------------------------------------------------------------------------

  Scenario: Each listed copy of a control needs its own removal
    When I add the control 243 twice in one list
    And I remove the control 243 from the disabled controls
    Then the control 243 should be disabled every frame

  @rejection
  Scenario: A control list with any invalid entry is ignored whole
    Then a control list mixing 243 with invalid entries should be ignored whole

  @rejection
  Scenario: Removing a control that is not listed changes nothing
    Then removing the unlisted control 243 should change nothing

  # Control 0 is the lowest valid id (INPUT_NEXT_CAMERA).
  Scenario: Control 0 can be disabled and released
    When I add the control 0 to the disabled controls
    Then the control 0 should be disabled every frame
    When I remove the control 0 from the disabled controls

  Scenario: Controls added through qb-smallresources reach the kora_utils list
    When I add the control 243 through the qb-smallresources exports
    Then the control 243 should be disabled every frame
    When I remove the control 243 from the disabled controls

  Scenario: Each listed copy of a HUD component needs its own removal
    When I add the HUD component 8 twice in one list
    And I remove the HUD component 8 from the hidden HUD components

  @rejection
  Scenario: A HUD component list with any invalid entry is ignored whole
    Then a HUD component list mixing 8 with invalid entries should be ignored whole

  @rejection
  Scenario: Removing a HUD component that is not hidden changes nothing
    Then removing the unlisted HUD component 8 should change nothing

  Scenario: HUD components hidden through qb-smallresources reach the kora_utils list
    When I add the HUD component 8 through the qb-smallresources exports
    And I remove the HUD component 8 from the hidden HUD components

  Scenario: Ammo display setting round-trips
    Then the ammo display setting should round-trip through kora_utils

  Scenario: Hands-up is reported while the hands-up animation plays
    Then kora_utils should report my hands "down"
    When I raise my hands
    Then kora_utils should report my hands "up"
    When I lower my hands
    Then kora_utils should report my hands "down"

  # ---------------------------------------------------------------------------
  # Wanted level and stance
  # ---------------------------------------------------------------------------

  @rejection
  Scenario: A wanted level cannot be raised
    Then raising my wanted level should leave it at 0

  Scenario: A short tap crouches and a second tap stands up
    When I tap the stance key to crouch
    Then I should be crouched
    And I should not be lying prone
    When I tap the stance key
    Then I should not be crouched

  Scenario: The crawl backward key plays the backward crawl while prone
    When I hold the stance key long enough to go prone
    Then I should be lying prone
    When I hold the crawl backward key
    Then I should be crawling backwards
    When I release the crawl backward key
    And I tap the stance key
    Then I should not be lying on the ground

  # ---------------------------------------------------------------------------
  # Timed jobs
  # ---------------------------------------------------------------------------

  @server
  Scenario: Timed jobs get increasing ids and stopping one leaves the other
    Given I schedule a timed job "first" that is not due soon
    And I schedule a timed job "second" that is not due soon
    Then the timed job "second" should have a later id than "first"
    When I stop the timed job "first"
    And I force the timed job "first" to run
    And I force the timed job "second" to run
    Then the timed job "first" should have run 0 times
    And the timed job "second" should have run 1 times

  @server
  Scenario: Stopping a timed job twice is harmless
    Given I schedule a timed job "once" that is not due soon
    When I stop the timed job "once"
    And I stop the timed job "once"
    And I force the timed job "once" to run
    Then the timed job "once" should have run 0 times

  @server
  Scenario: A failing timed job does not stop other timed jobs
    Given I expect a console error containing "fft timed job failure on purpose"
    # server/timedjobs.lua:10 logs the failure too; the job's message does not
    # survive the function-reference boundary, so its line ends in "nil".
    And I expect a console error from "kora_utils" containing "timed job from fft errored"
    And I schedule a failing timed job "faulty" that is not due soon
    And I schedule a timed job "healthy" that is not due soon
    When I force the timed job "faulty" to run
    And I force the timed job "healthy" to run
    And I force the timed job "faulty" to run
    Then the timed job "faulty" should have run 2 times
    And the timed job "healthy" should have run 1 times

  @server @rejection
  Scenario: Forcing or stopping an unknown timed job does nothing
    Then forcing and stopping an unknown timed job id should do nothing

  @server
  Scenario: Timed jobs scheduled through qb-smallresources run when forced
    Given I schedule a timed job "legacy" through qb-smallresources that is not due soon
    When I force the timed job "legacy" to run
    Then the timed job "legacy" should have run 1 times
