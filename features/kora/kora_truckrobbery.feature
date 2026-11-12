@kora @kora_truckrobbery
Feature: kora_truckrobbery armoured truck robbery
  A dealer ped starts a server-wide truck robbery when enough police are on
  duty. The dealer option is selected through kora_target's real targeting
  loop. Coordinates come from shared/config.lua (Config.DealerCoords) and are
  unverified until run live. Fighting the guards and looting the truck at the
  drop-off are not covered.

  Background:
    Given resource "kora_truckrobbery" is running
    And the truck robbery should be idle

  @server
  Scenario: Robbery state is published and idle
    Then the truck robbery should be idle

  @world
  Scenario: Dealer offers the robbery while none is running
    Given I face the truck robbery dealer
    Then the target option "start Robbery" should be visible

  @world @rejection
  Scenario: Dealer refuses without enough police on duty
    Given fewer police are on duty than the truck robbery needs
    And I face the truck robbery dealer
    And I target "start Robbery"
    Then I should see a notification containing "There are not enough police on duty."
    And the truck robbery should be idle

  # Starting publishes GlobalState.TruckRobbery to every client: the dealer option
  # is hidden for all players until the reset a few seconds later.
  @world @seam @global
  Scenario: Dealer starts the robbery and locks it for everyone
    Given the truck robbery police requirement is waived for my next attempt
    And I face the truck robbery dealer
    And I target "start Robbery"
    Then I should see a notification containing "A Truck Popped Up On Your GPS"
    And the truck robbery should be in progress with a configured route
    And the truck robbery truck and guards should have spawned for me
    When I aim at 960.78 -216.25 76.55
    Then no target option should be visible
    When the truck robbery truck and guards are removed
    And the truck robbery test state is reset
    Then the truck robbery should be idle

  # The refused event raises a server-side assert: expect one script error line
  # from kora_truckrobbery in the server console.
  @world @seam @global @rejection
  Scenario: Robbery cannot be finished away from the drop-off
    Given the truck robbery police requirement is waived for my next attempt
    And I face the truck robbery dealer
    And I target "start Robbery"
    Then the truck robbery should be in progress with a configured route
    And the truck robbery truck and guards should have spawned for me
    When I claim the truck robbery is finished without delivering the truck
    Then the truck robbery should still be in progress
    When the truck robbery truck and guards are removed
    And the truck robbery test state is reset
    Then the truck robbery should be idle

  @server @seam
  Scenario: Server reports the robbery idle and the police it needs
    Then the truck robbery server should report it idle and needing 2 police

  @world
  Scenario: Dealer stands at the configured spot
    Given I stand at 961.9 -216.25 76.25 facing 90.0
    Then the truck robbery dealer should stand at 960.78 -216.25 76.25

  @world @rejection
  Scenario: Refused start spawns no truck or guards
    Given fewer police are on duty than the truck robbery needs
    And I face the truck robbery dealer
    And I target "start Robbery"
    Then I should see a notification containing "There are not enough police on duty."
    And no robbery truck or guards should exist for me
    And the truck robbery should be idle

  @world @rejection
  Scenario: Start callback answers false without enough police
    Given fewer police are on duty than the truck robbery needs
    And I stand at 961.9 -216.25 76.25 facing 90.0
    When I ask the dealer to start the truck robbery
    Then the dealer should decline the truck robbery
    And the truck robbery should be idle

  # server/server.lua asserts the 5 m dealer distance; the raised assert is
  # printed by kora_lib's callback gateway. 798.18 -1799.87 29.33 is a
  # Config.VehicleSpawn point, far from the dealer.
  @world @rejection
  Scenario: Start callback is refused away from the dealer
    Given I expect a console error containing "is to far from the dealer"
    And I stand at 798.18 -1799.87 29.33 facing 0.0
    When I ask the dealer to start the truck robbery
    Then the dealer should fail the truck robbery with "is to far from the dealer"
    And the truck robbery should be idle

  # server/server.lua endRobbery asserts robData.inProgress first.
  @world @rejection
  Scenario: Finishing a robbery that never started is refused
    Given I expect a console error from "kora_truckrobbery" containing "No robbery in progress"
    And I stand at 961.9 -216.25 76.25 facing 90.0
    When I claim the truck robbery is finished from here
    Then the truck robbery should be idle

  @world @seam @global
  Scenario: Published route matches the server and comes from the config lists
    Given the truck robbery police requirement is waived for my next attempt
    And I stand at 961.9 -216.25 76.25 facing 90.0
    When I ask the dealer to start the truck robbery
    Then the dealer should accept the truck robbery
    And the truck robbery should be in progress with a configured route
    And the published truck robbery route should match the server
    When the truck robbery test state is reset
    Then the truck robbery should be idle

  @world @seam @global @rejection
  Scenario: A second start while a robbery runs is declined and keeps the route
    Given the truck robbery police requirement is waived for my next attempt
    And I stand at 961.9 -216.25 76.25 facing 90.0
    When I ask the dealer to start the truck robbery
    Then the dealer should accept the truck robbery
    And the truck robbery should be in progress with a configured route
    And I remember the truck robbery route
    When I ask the dealer to start the truck robbery
    Then the dealer should decline the truck robbery
    And the truck robbery route should be unchanged
    When the truck robbery test state is reset
    Then the truck robbery should be idle

  @world @seam @global @rejection
  Scenario: The police waiver covers one start only
    Given fewer police are on duty than the truck robbery needs
    And the truck robbery police requirement is waived for my next attempt
    And I stand at 961.9 -216.25 76.25 facing 90.0
    When I ask the dealer to start the truck robbery
    Then the dealer should accept the truck robbery
    When the truck robbery test state is reset
    Then the truck robbery should be idle
    When I ask the dealer to start the truck robbery
    Then the dealer should decline the truck robbery
    And the truck robbery should be idle

  # server/server.lua truckAtDropOff: the stockade itself must be within 10 m.
  @world @seam @global @rejection
  Scenario: Finishing at the drop-off without the truck is refused
    Given the truck robbery police requirement is waived for my next attempt
    And I stand at 961.9 -216.25 76.25 facing 90.0
    When I ask the dealer to start the truck robbery
    Then the dealer should accept the truck robbery
    And the truck robbery should be in progress with a configured route
    And I expect a console error from "kora_truckrobbery" containing "The robbery truck is not at the drop-off"
    When I stand at the truck robbery drop-off
    And I claim the truck robbery is finished from here
    Then the truck robbery should still be in progress
    When the truck robbery test state is reset
    Then the truck robbery should be idle

  @world @seam @global
  Scenario: Spawned truck carries three armed guards and a robbery blip
    Given the truck robbery police requirement is waived for my next attempt
    And I face the truck robbery dealer
    And I target "start Robbery"
    Then the truck robbery truck and guards should have spawned for me
    And the robbery truck should carry three armed guards and its blip
    When the truck robbery truck and guards are removed
    And the truck robbery test state is reset
    Then the truck robbery should be idle

  @world @seam @global
  Scenario: After a reset the dealer offers the robbery again
    Given the truck robbery police requirement is waived for my next attempt
    And I face the truck robbery dealer
    And I target "start Robbery"
    Then the truck robbery should be in progress with a configured route
    And the truck robbery truck and guards should have spawned for me
    When the truck robbery truck and guards are removed
    And the truck robbery test state is reset
    Then the truck robbery should be idle
    When I aim at 960.78 -216.25 76.55
    Then the target option "start Robbery" should be visible
