@kora @kora_scrapyard
Feature: kora_scrapyard wanted list and vehicle dismantling
  The scrapyard attendant hands out an hourly list of wanted models. Driving a
  listed, unowned vehicle into the delivery bay and choosing "Demolish Vehicle"
  runs a 28 to 37 second progress bar, removes the vehicle and pays materials.
  The list is driven at the NUI-callback level; the bay and the attendant are
  selected through kora_target. Every vehicle is a temporary client-spawned one.

  Positions come from Config.Locations[1] in kora_scrapyard/shared/config.lua
  (list ped 2403.51 3127.95 48.15, bay 2351.5 3132.96 48.2). The standing and
  aim points derived from them are unverified until run live.

  Not covered: cancelling the dismantle (kora_lib's hook has no progress-cancel
  action), the owned-vehicle refusal (a persisted player_vehicles row would be
  needed), the out-of-range server refusal (the bay option is only selectable
  inside the bay) and two workers claiming the same model (a second player).
  The passenger-seat refusal is covered with the tester alone in an empty car.

  Background:
    Given resource "kora_scrapyard" is running

  @ui @world
  Scenario: The attendant opens the wanted vehicle list
    Given I stand at 2404.9 3127.95 48.15 facing 90.0
    And I aim at 2403.51 3127.95 48.4
    When I target "Get Vehicle List"
    Then the app "kora_scrapyard:vehicleList" should be open
    When I close the app
    Then no app should be open

  @ui @world
  Scenario: Choosing a listed car explains where to bring it
    Given I stand at 2404.9 3127.95 48.15 facing 90.0
    And I aim at 2403.51 3127.95 48.4
    When I target "Get Vehicle List"
    Then the app "kora_scrapyard:vehicleList" should be open
    When I pick a car from the scrapyard vehicle list
    Then I should see a notification containing "is on the wanted list"
    And I close the app

  @ui @world @rejection
  Scenario: The list refuses a model that is not wanted
    Given I stand at 2404.9 3127.95 48.15 facing 90.0
    And I aim at 2403.51 3127.95 48.4
    When I target "Get Vehicle List"
    Then the app "kora_scrapyard:vehicleList" should be open
    When I trigger the app action "kora_scrapyard:confirm" on "fft_no_such_model"
    Then the app should answer with a "warning" notice containing "no longer on the wanted list"
    When I trigger the app action "kora_scrapyard:confirm"
    Then the app should answer with a "destructive" notice containing "Could not read the selected vehicle"
    And I should not see a notification containing "is on the wanted list"
    And I close the app

  @world @rejection
  Scenario: The bay offers nothing to a player on foot
    Given I stand at 2351.5 3132.96 48.2 facing 270.0
    And I aim at 2352.8 3132.96 47.5
    Then no target option should be visible

  @world @rejection
  Scenario: A vehicle that is not on the list is refused
    Given I stand at 2351.5 3132.96 48.2 facing 270.0
    And I am driving a temporary "adder"
    And I wait 1500 milliseconds
    And I remember my scrap materials
    And I aim at 2352.8 3132.96 47.5
    When I target "Demolish Vehicle"
    Then I should see a notification containing "no longer on the scrapyard list"
    And no progress bar should be running
    And my temporary vehicle should still exist
    And I should not have gained scrap materials

  # Uses up one entry of the shared hourly list, which other players can see.
  @ui @world @slow @global
  Scenario: Dismantling a listed car removes it and pays materials
    Given I stand at 2404.9 3127.95 48.15 facing 90.0
    And I aim at 2403.51 3127.95 48.4
    When I target "Get Vehicle List"
    Then the app "kora_scrapyard:vehicleList" should be open
    When I pick a car from the scrapyard vehicle list
    And I close the app
    And I stand at 2351.5 3132.96 48.2 facing 270.0
    And I am driving a temporary car of the picked scrapyard model
    And I wait 1500 milliseconds
    And I remember my scrap materials
    And I aim at 2352.8 3132.96 47.5
    And I target "Demolish Vehicle"
    Then a progress bar labelled "Demolish Vehicle" should start
    When I wait 12000 milliseconds
    And I wait 12000 milliseconds
    Then the progress bar should finish
    And I should see a notification containing "Vehicle scrapped"
    And the scrapyard should have removed my vehicle
    And I should have gained at least 25 scrap materials

  # ---------------------------------------------------------------------------
  # Round 3: list contents and refusals, bay refusals, attendant and blip.
  # ---------------------------------------------------------------------------

  @ui @world
  Scenario: The wanted list shows this hour's cars with the configured layout
    Given I stand at 2404.9 3127.95 48.15 facing 90.0
    And I aim at 2403.51 3127.95 48.4
    When I target "Get Vehicle List"
    Then the scrapyard vehicle list should show the wanted cars
    When I close the app
    Then no app should be open

  # Matching is exact (client/vehiclelist.lua onAction), and an unlisted answer
  # carries a refreshed list.
  @ui @world @rejection
  Scenario Outline: The list only recognises exact model names
    Given I stand at 2404.9 3127.95 48.15 facing 90.0
    And I aim at 2403.51 3127.95 48.4
    When I target "Get Vehicle List"
    Then the app "kora_scrapyard:vehicleList" should be open
    When I trigger the app action "kora_scrapyard:confirm" on "<model>"
    Then the app should answer with a "warning" notice containing "That vehicle is no longer on the wanted list."
    And the scrapyard list answer should carry a refreshed list
    And I should not see a notification containing "is on the wanted list"
    And I close the app

    Examples:
      | model |
      | ASEA  |
      | Panto |
      | adder |

  @ui @world @rejection
  Scenario: The list refuses an empty selection and undeclared actions
    Given I stand at 2404.9 3127.95 48.15 facing 90.0
    And I aim at 2403.51 3127.95 48.4
    When I target "Get Vehicle List"
    Then the app "kora_scrapyard:vehicleList" should be open
    When I trigger the app action "kora_scrapyard:confirm" on ""
    Then the app should answer with a "destructive" notice containing "Could not read the selected vehicle."
    And the app action "kora_scrapyard:sell" should be unavailable
    And the app action "kora_scrapyard:dismantle" should be unavailable
    And I close the app

  @world
  Scenario: The attendant stands at the list point
    Given I stand at 2404.9 3127.95 48.15 facing 90.0
    Then the scrapyard attendant should stand at the list point
    When I aim at 2403.51 3127.95 48.4
    Then the target option "Get Vehicle List" should be visible

  Scenario: The scrapyard is marked on the map
    Then the scrapyard should be marked on the map

  @world @rejection
  Scenario: A passenger cannot demolish a vehicle
    Given I stand at 2351.5 3132.96 48.2 facing 270.0
    And I sit as a passenger in a temporary "asea"
    And I wait 1500 milliseconds
    And I remember my scrap materials
    And I aim at 2352.8 3132.96 47.5
    When I target "Demolish Vehicle"
    Then I should see a notification containing "You Are Not The Driver"
    And no progress bar should be running
    And my temporary vehicle should still exist
    And I should not have gained scrap materials

  # The passenger check runs on the client before the server is asked, so a
  # listed car is refused the same way and its listing is not claimed.
  @ui @world @rejection
  Scenario: A passenger in a listed car is refused and the car stays listed
    Given I stand at 2404.9 3127.95 48.15 facing 90.0
    And I aim at 2403.51 3127.95 48.4
    When I target "Get Vehicle List"
    Then the app "kora_scrapyard:vehicleList" should be open
    When I pick a car from the scrapyard vehicle list
    And I close the app
    And I stand at 2351.5 3132.96 48.2 facing 270.0
    And I sit as a passenger in a temporary car of the picked scrapyard model
    And I wait 1500 milliseconds
    And I remember my scrap materials
    And I aim at 2352.8 3132.96 47.5
    And I target "Demolish Vehicle"
    Then I should see a notification containing "You Are Not The Driver"
    And no progress bar should be running
    And my temporary vehicle should still exist
    And I should not have gained scrap materials

  # validateScrap (server/server.lua) refuses a configured model that is not on
  # this hour's list, before any progress bar.
  @ui @world @rejection
  Scenario: A configured car that is not listed this hour is refused at the bay
    Given I stand at 2404.9 3127.95 48.15 facing 90.0
    And I aim at 2403.51 3127.95 48.4
    When I target "Get Vehicle List"
    Then the app "kora_scrapyard:vehicleList" should be open
    When I pick a configured car that is not on the scrapyard list
    And I close the app
    And I stand at 2351.5 3132.96 48.2 facing 270.0
    And I am driving a temporary car of the picked scrapyard model
    And I wait 1500 milliseconds
    And I remember my scrap materials
    And I aim at 2352.8 3132.96 47.5
    When I target "Demolish Vehicle"
    Then I should see a notification containing "no longer on the scrapyard list"
    And no progress bar should be running
    And my temporary vehicle should still exist
    And I should not have gained scrap materials

  @world @rejection
  Scenario Outline: Vehicles the scrapyard never lists are refused at the bay
    Given I stand at 2351.5 3132.96 48.2 facing 270.0
    And I am driving a temporary "<model>"
    And I wait 1500 milliseconds
    And I remember my scrap materials
    And I aim at 2352.8 3132.96 47.5
    When I target "Demolish Vehicle"
    Then I should see a notification containing "no longer on the scrapyard list"
    And no progress bar should be running
    And my temporary vehicle should still exist
    And I should not have gained scrap materials

    Examples:
      | model   |
      | t20     |
      | faggio  |
      | burrito |
