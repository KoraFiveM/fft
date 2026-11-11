@kora @kora_businesses
Feature: kora_businesses bundled jobs
  The jobs kora_businesses loads from its config: mechanic services, the taxi
  rank, the garbage depot, the tow yard and the recycle centre. Each is driven
  through the surface a player uses (target options, the interact selector,
  progress bars, dialogs, the recycle buyer's app) and asserted on vehicles,
  notifications and server-owned money and items.

  Fixtures: the tester's job is set per scenario and restored afterwards. Job
  vehicles are handed back through the job's own option (Return Taxi, Store
  Vehicle, losing the garbage job); deleting any that are left is only a safety
  net. Mechanic scenarios work on a throwaway vehicle that is deleted afterwards.
  A recycle sale adds the sold amount to the buyer's shared stock counter.

  Server callbacks and events are also driven directly as the tester (permits,
  service completions, taxi/tow/garbage/recycle/CCTV callbacks), asserting the
  server's own answers. "Through the server protocol" scenarios repeat the job
  client's call sequence at truthful, teleported positions without its vehicle
  props (no flatbed load, no carried box); every server check still applies.
  The tow and garbage protocol scenarios hand their job back through the
  server's own ReturnVehicle / cancel callbacks.

  Not covered:
  - The taxi fare itself: qb-taxi:getPickupLocation stores a fare for the
    tester that only a drop-off or a relog clears, so it is never requested.
  - The tow "Detach Vehicle" option: it calls qb-tow:server:CheckDistance,
    which no server file registers.
  - Mechanic permit rate limit (8 per 10 s): the burst would also starve the
    neighbouring scenarios' permits.
  - Passive vehicle wear, limp mode and random tyre bursts: driving physics and chance.
  - CCTV engineer flows: the cctv job is not defined in kora_core on this
    server, hacking moves the player's routing bucket, and call-outs charge
    society accounts. Only refusals to a non-engineer are covered, with at most
    two call-out requests per run (the callback allows 3 per minute).
  - Hot dog stand: not loaded by this server's config.

  Background:
    Given resource "kora_businesses" is running

  # --- Mechanic -------------------------------------------------------------

  @world @ui @slow
  Scenario: An on-duty mechanic completes a full repair in a garage bay
    Given I am on duty as "mechanic" at grade 1
    And I stand at -211.6 -1324.31 30.89 facing 270.0
    And a damaged test vehicle is parked in front of me
    When I service the test vehicle with "Full garage repair"
    Then a progress bar labelled "Perform full repair" should start
    When I wait 12000 milliseconds
    Then the progress bar should finish
    And I should see a notification containing "Full repair completed"
    And the test vehicle engine health should be at least 1000

  @world @rejection
  Scenario: A full repair is refused away from a garage bay
    Given I am on duty as "mechanic" at grade 1
    And I stand at -333.84 -1527.28 28.3 facing 0.0
    And a damaged test vehicle is parked in front of me
    When I service the test vehicle with "Full garage repair"
    Then I should see a notification containing "garage bay"
    And no progress bar should be running
    And the test vehicle engine health should be below 400

  @world @ui @slow
  Scenario: Roadside staff stabilise a vehicle but cannot fully repair it
    Given I am on duty as "roadside" at grade 1
    And I stand at -333.84 -1527.28 28.3 facing 0.0
    And a damaged test vehicle is parked in front of me
    Then the test vehicle should not offer "Full garage repair"
    When I service the test vehicle with "Roadside stabilisation"
    Then a progress bar labelled "Stabilise vehicle" should start
    When I wait 7000 milliseconds
    Then the progress bar should finish
    And I should see a notification containing "Vehicle stabilised"
    And the test vehicle engine health should be at least 650
    And the test vehicle engine health should be below 1000

  @world @rejection
  Scenario: An off-duty mechanic is offered no vehicle services
    Given I am off duty as "mechanic" at grade 1
    And I stand at -333.84 -1527.28 28.3 facing 0.0
    And a damaged test vehicle is parked in front of me
    Then the test vehicle should not offer "Full garage repair"
    And the test vehicle should not offer "Roadside stabilisation"

  @world @ui @slow
  Scenario: Bodyshop staff respray a vehicle in a garage bay
    Given I am on duty as "bodyshop" at grade 1
    And I stand at -211.6 -1324.31 30.89 facing 270.0
    And a damaged test vehicle is parked in front of me
    Then the test vehicle should not offer "Full garage repair"
    When I service the test vehicle with "Respray vehicle"
    Then an input dialog should open
    When I submit the input dialog with:
      """
      { "primary": 27, "secondary": 111 }
      """
    Then a progress bar labelled "Respraying vehicle" should start
    When I wait 10000 milliseconds
    Then the progress bar should finish
    And I should see a notification containing "Respray completed"
    And the test vehicle should be painted 27 and 111

  @world @rejection
  Scenario: Bodyshop staff are not offered a respray away from a garage bay
    Given I am on duty as "bodyshop" at grade 1
    And I stand at -333.84 -1527.28 28.3 facing 0.0
    And a damaged test vehicle is parked in front of me
    Then the test vehicle should not offer "Respray vehicle"

  # --- Taxi -----------------------------------------------------------------

  @world @ui
  Scenario: A taxi driver takes a cab from the rank and returns it
    Given my job is "taxi" at grade 1
    When I walk into the taxi rank bay
    Then the interact selector should offer "Spawn Taxi"
    When I choose "Spawn Taxi" in the interact selector
    Then I should be driving a job vehicle plated "TAXI"
    And I should not see a notification containing "You must be on duty as a taxi driver"
    When I walk into the taxi rank bay
    And I choose "Return Taxi" in the interact selector
    Then no new job vehicle plated "TAXI" should remain near me

  @world @ui @rejection
  Scenario: The rank takes the cab back from someone who is not a taxi driver
    Given my job is "unemployed" at grade 1
    When I walk into the taxi rank bay
    And I choose "Spawn Taxi" in the interact selector
    Then I should see a notification containing "You must be on duty as a taxi driver"
    And no new job vehicle plated "TAXI" should be issued to me

  # --- Garbage --------------------------------------------------------------

  @world
  Scenario: A garbage worker starts a route and loses the truck with the job
    Given my job is "garbage" at grade 1
    And I stand at -320.88 -1545.39 30.02 facing 114.97
    And I note the job vehicles plated "GARBAGE" around me
    When I aim at -322.24 -1546.02 30.4
    And I target "Start Garbage Route"
    Then I should see a notification containing "Your truck is ready"
    And a new job vehicle plated "GARBAGE" should appear near me
    When my job is "unemployed" at grade 1
    Then no new job vehicle plated "GARBAGE" should remain near me

  @world @rejection
  Scenario: The depot foreman offers no route to someone without the garbage job
    Given my job is "unemployed" at grade 1
    And I stand at -320.88 -1545.39 30.02 facing 114.97
    When I aim at -322.24 -1546.02 30.4
    Then no target option should be visible

  # --- Tow ------------------------------------------------------------------

  @world @ui @slow
  Scenario: A tow driver pulls out a flatbed and stores it unpaid
    Given my job is "tow" at grade 1
    And I remember my "bank" balance
    When I walk into the tow yard bay
    And I choose "Pull Out Vehicle" in the interact selector
    Then I should be driving a job vehicle plated "TOW"
    And I should see a notification containing "New tow vehicle marked on your map"
    When I wait 5500 milliseconds
    And I walk into the tow yard bay
    And I choose "Store Vehicle" in the interact selector
    Then no new job vehicle plated "TOW" should remain near me
    And my "bank" balance should be unchanged

  @world @ui @rejection
  Scenario: The tow yard gives no flatbed to someone without the tow job
    Given my job is "unemployed" at grade 1
    When I walk into the tow yard bay
    And I choose "Pull Out Vehicle" in the interact selector
    Then no new job vehicle plated "TOW" should be issued to me
    And I should not see a notification containing "New tow vehicle marked on your map"

  # --- Recycle --------------------------------------------------------------

  @world @ui @global
  Scenario: The recycle buyer pays two dollars per material in cash
    Given I hold 5 "metalscrap"
    And I remember my "cash" balance
    And I remember how many "metalscrap" I have
    And I stand at 1049.84 -3095.6 -39.0 facing 0.0
    When I aim at 1049.84 -3094.08 -39.2
    And I target "Sell Materials"
    Then the app "kora_businesses:recycle:sell" should be open
    When I trigger the app action "kora_businesses:recycle:sellItem" with:
      """
      { "itemId": "material:metalscrap", "value": { "amount": 3 } }
      """
    Then my "cash" balance should have increased by 6
    And I should have 3 fewer "metalscrap" than before

  @world @ui @rejection
  Scenario: The recycle buyer refuses more material than the seller holds
    Given I hold 2 "plastic"
    And I remember my "cash" balance
    And I remember how many "plastic" I have
    And I stand at 1049.84 -3095.6 -39.0 facing 0.0
    When I aim at 1049.84 -3094.08 -39.2
    And I target "Sell Materials"
    Then the app "kora_businesses:recycle:sell" should be open
    When I trigger the app action "kora_businesses:recycle:sellItem" with:
      """
      { "itemId": "material:plastic", "value": { "amount": 499 } }
      """
    Then the recycling buyer should answer with a "destructive" notice containing "You only have"
    And my "cash" balance should be unchanged
    And I should have 0 fewer "plastic" than before

  @world
  Scenario: The recycle centre duty point clocks a worker in and out
    Given I stand at 1050.6 -3100.62 -39.0 facing 90.0
    When I aim at 1048.7 -3100.62 -38.6
    And I target "Toggle Duty"
    Then I should see a notification containing "You Have Clocked"
    When I wait 1500 milliseconds
    And I aim at 1048.7 -3100.62 -38.6
    And I target "Toggle Duty"
    Then I should have clocked in and out of the recycling centre once each

  # ===========================================================================
  # Server callbacks and events, driven directly as the tester. Scenarios that
  # say "through the server protocol" repeat the job client's own call sequence
  # (jobs/*/client.lua) at truthful positions without its vehicle props; every
  # server check still applies.
  # ===========================================================================

  # --- Mechanic: service permits ---------------------------------------------

  @world @rejection
  Scenario Outline: The permit server refuses a vehicle service outside the role's remit
    Given I am on duty as "<job>" at grade 1
    And I stand at <x> <y> <z> facing <h>
    And a damaged test vehicle is parked in front of me
    When I request a "<action>" service permit for the test vehicle
    Then the kora_businesses callback should refuse with "<reason>"
    And the test vehicle engine health should be below 400

    Examples:
      | job      | x       | y        | z     | h     | action         | reason                                                        |
      | roadside | -211.6  | -1324.31 | 30.89 | 270.0 | fullRepair     | Only a qualified mechanic can complete a full repair.         |
      | bodyshop | -211.6  | -1324.31 | 30.89 | 270.0 | fullRepair     | Only a qualified mechanic can complete a full repair.         |
      | mechanic | -333.84 | -1527.28 | 28.3  | 0.0   | fullRepair     | A full repair must be completed in a Mechanicured garage bay. |
      | bodyshop | -333.84 | -1527.28 | 28.3  | 0.0   | roadsideRepair | Only automotive staff can stabilise a vehicle.                |
      | mechanic | -211.6  | -1324.31 | 30.89 | 270.0 | paint          | Only bodyshop staff can change vehicle cosmetics.             |
      | roadside | -211.6  | -1324.31 | 30.89 | 270.0 | bumpers        | Only bodyshop staff can change vehicle cosmetics.             |
      | bodyshop | -333.84 | -1527.28 | 28.3  | 0.0   | paint          | Cosmetic work must be done at a mechanic shop.                |
      | bodyshop | -333.84 | -1527.28 | 28.3  | 0.0   | bumpers        | Cosmetic work must be done at a mechanic shop.                |
      | mechanic | -211.6  | -1324.31 | 30.89 | 270.0 | tuneEngine     | Unknown vehicle service action.                               |

  @world
  Scenario Outline: The permit server authorises a service within the role's remit without applying it
    Given I am on duty as "<job>" at grade 1
    And I stand at <x> <y> <z> facing <h>
    And a damaged test vehicle is parked in front of me
    When I request a "<action>" service permit for the test vehicle
    Then the service permit should be granted
    And the test vehicle engine health should be below 400

    Examples:
      | job      | x       | y        | z     | h     | action         |
      | mechanic | -211.6  | -1324.31 | 30.89 | 270.0 | fullRepair     |
      | mechanic | -333.84 | -1527.28 | 28.3  | 0.0   | roadsideRepair |
      | roadside | -333.84 | -1527.28 | 28.3  | 0.0   | roadsideRepair |
      | bodyshop | -211.6  | -1324.31 | 30.89 | 270.0 | paint          |
      | bodyshop | -211.6  | -1324.31 | 30.89 | 270.0 | bumpers        |

  @world @rejection
  Scenario: The permit server refuses an off-duty mechanic
    Given I am off duty as "mechanic" at grade 1
    And I stand at -211.6 -1324.31 30.89 facing 270.0
    And a damaged test vehicle is parked in front of me
    When I request a "fullRepair" service permit for the test vehicle
    Then the kora_businesses callback should refuse with "You must be on duty to do that."

  @rejection
  Scenario: The permit server refuses a vehicle that does not exist
    Given I am on duty as "mechanic" at grade 1
    When I request a "roadsideRepair" service permit for vehicle network id 0
    Then the kora_businesses callback should refuse with "Move closer to a valid vehicle."

  # --- Mechanic: service completion -----------------------------------------

  @world @rejection
  Scenario: A service completion with a forged permit is refused
    Given I am on duty as "bodyshop" at grade 1
    And I stand at -211.6 -1324.31 30.89 facing 270.0
    And a damaged test vehicle is parked in front of me
    And I note the test vehicle paint
    When I complete the vehicle service with the permit "fft:forged:permit" and:
      """
      { "primary": 27, "secondary": 111 }
      """
    Then I should see a notification containing "That service authorisation expired"
    And the test vehicle paint should be unchanged

  @world @rejection
  Scenario Outline: A respray completion with an invalid colour is refused
    Given I am on duty as "bodyshop" at grade 1
    And I stand at -211.6 -1324.31 30.89 facing 270.0
    And a damaged test vehicle is parked in front of me
    And I note the test vehicle paint
    When I request a "paint" service permit for the test vehicle
    Then the service permit should be granted
    When I complete the vehicle service with my permit and:
      """
      <payload>
      """
    Then I should see a notification containing "The requested vehicle modification is invalid."
    And the test vehicle paint should be unchanged

    Examples:
      | payload                              |
      | { "primary": 161, "secondary": 0 }   |
      | { "primary": 0, "secondary": -1 }    |
      | { "primary": 1.5, "secondary": 0 }   |
      | { "primary": "12", "secondary": 0 }  |
      | { "primary": 12 }                    |

  @world @rejection
  Scenario Outline: A bumper completion with an invalid variation is refused
    Given I am on duty as "bodyshop" at grade 1
    And I stand at -211.6 -1324.31 30.89 facing 270.0
    And a damaged test vehicle is parked in front of me
    When I request a "bumpers" service permit for the test vehicle
    Then the service permit should be granted
    When I complete the vehicle service with my permit and:
      """
      <payload>
      """
    Then I should see a notification containing "The requested vehicle modification is invalid."
    And the test vehicle should have stock bumpers

    Examples:
      | payload                     |
      | { "front": 51, "rear": 0 }  |
      | { "front": 0, "rear": -2 }  |
      | { "front": 0.5, "rear": 0 } |

  @world @rejection
  Scenario: A service permit is single-use even when its completion was refused
    Given I am on duty as "bodyshop" at grade 1
    And I stand at -211.6 -1324.31 30.89 facing 270.0
    And a damaged test vehicle is parked in front of me
    And I note the test vehicle paint
    When I request a "paint" service permit for the test vehicle
    Then the service permit should be granted
    When I complete the vehicle service with my permit and:
      """
      { "primary": 999, "secondary": 0 }
      """
    Then I should see a notification containing "The requested vehicle modification is invalid."
    When I complete the vehicle service with my permit and:
      """
      { "primary": 27, "secondary": 111 }
      """
    Then I should see a notification containing "That service authorisation expired"
    And the test vehicle paint should be unchanged

  @world @rejection
  Scenario: Clocking off after the permit voids the service
    Given I am on duty as "bodyshop" at grade 1
    And I stand at -211.6 -1324.31 30.89 facing 270.0
    And a damaged test vehicle is parked in front of me
    And I note the test vehicle paint
    When I request a "paint" service permit for the test vehicle
    Then the service permit should be granted
    When I am off duty as "bodyshop" at grade 1
    When I complete the vehicle service with my permit and:
      """
      { "primary": 27, "secondary": 111 }
      """
    Then I should see a notification containing "You must be on duty to do that."
    And the test vehicle paint should be unchanged

  # --- Mechanic: services through the target UI -----------------------------

  @world @ui @slow
  Scenario Outline: Bodyshop staff respray with the palette boundary colours
    Given I am on duty as "bodyshop" at grade 1
    And I stand at -211.6 -1324.31 30.89 facing 270.0
    And a damaged test vehicle is parked in front of me
    When I service the test vehicle with "Respray vehicle"
    Then an input dialog should open
    When I submit the input dialog with:
      """
      { "primary": <primary>, "secondary": <secondary> }
      """
    Then a progress bar labelled "Respraying vehicle" should start
    When I wait 12000 milliseconds
    Then the progress bar should finish
    And I should see a notification containing "Respray completed"
    And the test vehicle should be painted <primary> and <secondary>

    Examples:
      | primary | secondary |
      | 0       | 160       |
      | 160     | 0         |

  @world @ui @rejection
  Scenario: Cancelling the respray dialog starts no service
    Given I am on duty as "bodyshop" at grade 1
    And I stand at -211.6 -1324.31 30.89 facing 270.0
    And a damaged test vehicle is parked in front of me
    And I note the test vehicle paint
    When I service the test vehicle with "Respray vehicle"
    Then an input dialog should open
    When I cancel the input dialog
    Then no progress bar should be running
    And the test vehicle paint should be unchanged

  @world @ui @slow
  Scenario: Bodyshop staff fit stock bumpers in a garage bay
    Given I am on duty as "bodyshop" at grade 1
    And I stand at -211.6 -1324.31 30.89 facing 270.0
    And a damaged test vehicle is parked in front of me
    When I service the test vehicle with "Customise bumpers"
    Then an input dialog should open
    When I submit the input dialog with:
      """
      { "front": -1, "rear": -1 }
      """
    Then a progress bar labelled "Fitting bumper components" should start
    When I wait 12000 milliseconds
    Then the progress bar should finish
    And I should see a notification containing "Bumper customisation completed."
    And the test vehicle should have stock bumpers

  @world @ui @slow
  Scenario: A mechanic stabilises a vehicle away from a bay up to the roadside floors
    Given I am on duty as "mechanic" at grade 1
    And I stand at -333.84 -1527.28 28.3 facing 0.0
    And a damaged test vehicle is parked in front of me
    When I service the test vehicle with "Roadside stabilisation"
    Then a progress bar labelled "Stabilise vehicle" should start
    When I wait 7000 milliseconds
    Then the progress bar should finish
    And I should see a notification containing "Vehicle stabilised"
    And the test vehicle engine health should be at least 650
    And the test vehicle body health should be at least 500
    And the test vehicle body health should be below 1000

  @world @ui @slow
  Scenario Outline: Roadside stabilisation fixes a burst tyre
    Given I am on duty as "roadside" at grade 1
    And I stand at -333.84 -1527.28 28.3 facing 0.0
    And a damaged test vehicle is parked in front of me
    And the test vehicle has a burst tyre at wheel index <wheel>
    When I service the test vehicle with "Roadside stabilisation"
    Then a progress bar labelled "Stabilise vehicle" should start
    When I wait 7000 milliseconds
    Then the progress bar should finish
    And I should see a notification containing "Vehicle stabilised"
    And the test vehicle tyre at wheel index <wheel> should not be burst

    Examples:
      | wheel |
      | 0     |
      | 4     |

  @world @rejection
  Scenario Outline: People outside the motor trade are offered no vehicle services
    Given my job is "<job>" at grade 1
    And I stand at -211.6 -1324.31 30.89 facing 270.0
    And a damaged test vehicle is parked in front of me
    Then the test vehicle should not offer "Full garage repair"
    And the test vehicle should not offer "Roadside stabilisation"
    And the test vehicle should not offer "Respray vehicle"
    And the test vehicle should not offer "Customise bumpers"

    Examples:
      | job        |
      | unemployed |
      | police     |

  @world @rejection
  Scenario: A mechanic is not offered cosmetic work in a garage bay
    Given I am on duty as "mechanic" at grade 1
    And I stand at -211.6 -1324.31 30.89 facing 270.0
    And a damaged test vehicle is parked in front of me
    Then the test vehicle should not offer "Respray vehicle"
    And the test vehicle should not offer "Customise bumpers"

  # --- Taxi -------------------------------------------------------------------

  @rejection
  Scenario Outline: The taxi server hands no fare to other jobs
    Given my job is "<job>" at grade 1
    When I call the kora_businesses callback "qb-taxi:getPickupLocation"
    Then the kora_businesses callback should answer nothing

    Examples:
      | job        |
      | unemployed |
      | tow        |
      | garbage    |

  # --- Tow --------------------------------------------------------------------

  @rejection
  Scenario Outline: Tow job steps are refused without a tow vehicle out
    Given my job is "tow" at grade 1
    And the tow server will refuse on the console with "Player does not have a tow vehicle out"
    When I call the kora_businesses callback "<callback>"
    Then the kora_businesses callback should fail with "Player does not have a tow vehicle out"

    Examples:
      | callback                     |
      | qb-tow:server:pickUp         |
      | qb-tow:server:DropOff        |
      | qb-tow:server:ReturnVehicle  |

  @world @rejection
  Scenario: A tow job is refused away from the tow yard
    Given my job is "tow" at grade 1
    And the tow server will refuse on the console with "Player is too far from the vehicle location"
    And the tow server will refuse on the console with "Player does not have a tow vehicle out"
    And any tow job issued to me is handed back afterwards
    And I stand at -333.84 -1527.28 28.3 facing 0.0
    And I wait 1500 milliseconds
    When I call the kora_businesses callback "qb-tow:server:TakeOutVehicle"
    Then the kora_businesses callback should fail with "Player is too far from the vehicle location"
    When I call the kora_businesses callback "qb-tow:server:pickUp"
    Then the kora_businesses callback should fail with "Player does not have a tow vehicle out"

  @world @rejection
  Scenario Outline: The tow yard issues no tow job to other jobs
    Given my job is "<job>" at grade 1
    And the tow server will refuse on the console with "Player does not have a tow vehicle out"
    And any tow job issued to me is handed back afterwards
    And I stand at 489.65 -1331.82 29.33 facing 0.0
    And I wait 1500 milliseconds
    When I call the kora_businesses callback "qb-tow:server:TakeOutVehicle"
    Then the kora_businesses callback should answer nothing
    When I call the kora_businesses callback "qb-tow:server:pickUp"
    Then the kora_businesses callback should fail with "Player does not have a tow vehicle out"

    Examples:
      | job        |
      | unemployed |
      | taxi       |
      | garbage    |

  @world @rejection
  Scenario: A second tow job is refused while one is out
    Given my job is "tow" at grade 1
    And the tow server will refuse on the console with "Player already has a tow vehicle out"
    When I take out a tow job through the server protocol
    And I call the kora_businesses callback "qb-tow:server:TakeOutVehicle"
    Then the kora_businesses callback should fail with "Player already has a tow vehicle out"

  @world @rejection
  Scenario: A drop-off before any pickup is refused
    Given my job is "tow" at grade 1
    And the tow server will refuse on the console with "Player has not picked up a vehicle"
    When I take out a tow job through the server protocol
    And I call the kora_businesses callback "qb-tow:server:DropOff"
    Then the kora_businesses callback should fail with "Player has not picked up a vehicle"

  @world @rejection
  Scenario: A pickup away from the assigned tow spot is refused
    Given my job is "tow" at grade 1
    When I take out a tow job through the server protocol
    And I stand at a tow spot other than mine
    And I call the kora_businesses callback "qb-tow:server:pickUp"
    Then the kora_businesses callback should answer false

  @world
  Scenario: Returning a tow job with no drop-offs pays nothing
    Given my job is "tow" at grade 1
    And the tow server will refuse on the console with "Player does not have a tow vehicle out"
    And I remember my "bank" balance
    When I take out a tow job through the server protocol
    And I call the kora_businesses callback "qb-tow:server:ReturnVehicle"
    Then the kora_businesses callback should answer true
    And my "bank" balance should be unchanged
    When I call the kora_businesses callback "qb-tow:server:ReturnVehicle"
    Then the kora_businesses callback should fail with "Player does not have a tow vehicle out"

  @world @slow
  Scenario: A towed vehicle pays one hundred to the bank through the server protocol
    Given my job is "tow" at grade 1
    And I remember my "bank" balance
    When I take out a tow job through the server protocol
    And I go to my tow spot and pick up the vehicle through the server protocol
    And I drop the vehicle at the tow yard through the server protocol
    And I call the kora_businesses callback "qb-tow:server:ReturnVehicle"
    Then the kora_businesses callback should answer true
    And I should see a notification containing "You received $100 for 1 vehicle(s)."
    And my "bank" balance should have increased by 100

  # --- Garbage ----------------------------------------------------------------

  @rejection
  Scenario Outline: The depot issues no garbage route to other jobs
    Given my job is "<job>" at grade 1
    When I call the kora_businesses callback "qb-garbagejob:spawnTruck"
    Then the kora_businesses callback should answer false

    Examples:
      | job        |
      | unemployed |
      | tow        |
      | taxi       |

  @rejection
  Scenario: Cancelling without a garbage route is harmless and repeatable
    Given my job is "garbage" at grade 1
    When I call the kora_businesses callback "qb-garbagejob:cancel"
    Then the kora_businesses callback should answer true
    When I call the kora_businesses callback "qb-garbagejob:cancel"
    Then the kora_businesses callback should answer true

  @rejection
  Scenario Outline: Garbage route steps are refused without a route
    Given my job is "garbage" at grade 1
    And I call the kora_businesses callback "qb-garbagejob:cancel"
    When I call the kora_businesses callback "<callback>" with:
      """
      [<argument>]
      """
    Then the kora_businesses callback should answer false

    Examples:
      | callback                    | argument |
      | qb-garbagejob:setTruck      | 1        |
      | qb-garbagejob:collectBag    | 1        |
      | qb-garbagejob:depositBag    | 1        |
      | qb-garbagejob:completeStop  | 1        |
      | qb-garbagejob:returnTruck   | 1        |

  @world
  Scenario: A garbage route has five or six distinct stops and only one runs at a time
    Given my job is "garbage" at grade 1
    When I start a garbage route through the server protocol
    Then my garbage route should have 5 to 6 distinct stops of 1 to 4 bags
    When I call the kora_businesses callback "qb-garbagejob:spawnTruck"
    Then the kora_businesses callback should answer false

  @world @rejection
  Scenario Outline: The depot refuses an invalid garbage truck
    Given my job is "garbage" at grade 1
    When I start a garbage route through the server protocol
    And I try to register network id <netId> as my garbage truck
    Then the kora_businesses callback should answer false

    Examples:
      | netId |
      | 0     |
      | -5    |

  @world @rejection
  Scenario: The depot refuses a vehicle that is not a garbage truck
    Given my job is "garbage" at grade 1
    When I start a garbage route through the server protocol
    And a damaged test vehicle is parked in front of me
    And I try to register the test vehicle as my garbage truck
    Then the kora_businesses callback should answer false

  @world @rejection
  Scenario: A registered garbage truck cannot be registered twice
    Given my job is "garbage" at grade 1
    When I start a garbage route through the server protocol
    And I register my own garbage truck through the server protocol
    And I try to register my garbage truck again
    Then the kora_businesses callback should answer false

  @world @rejection
  Scenario: Garbage bags are only collected at the current stop and in reach
    Given my job is "garbage" at grade 1
    When I start a garbage route through the server protocol
    And I collect a bag at my first garbage stop from the depot
    Then the kora_businesses callback should answer false
    When I try to collect a bag at a trashcan that is not my current stop
    Then the kora_businesses callback should answer false

  @world @rejection
  Scenario: An unfinished garbage stop or route cannot be completed
    Given my job is "garbage" at grade 1
    When I start a garbage route through the server protocol
    And I register my own garbage truck through the server protocol
    And I try to complete garbage route stop 1
    Then the kora_businesses callback should answer false
    When I try to complete garbage route stop 2
    Then the kora_businesses callback should answer false
    When I try to return my garbage truck
    Then the kora_businesses callback should answer false

  @world @slow
  Scenario: A finished garbage route pays fifty per stop to the bank through the server protocol
    Given my job is "garbage" at grade 1
    And I remember my "bank" balance
    When I start a garbage route through the server protocol
    And I register my own garbage truck through the server protocol
    And I clear the next garbage stop through the server protocol
    And I clear the next garbage stop through the server protocol
    And I clear the next garbage stop through the server protocol
    And I clear the next garbage stop through the server protocol
    And I clear the next garbage stop through the server protocol
    And I clear the next garbage stop through the server protocol
    And I return my garbage truck at the depot through the server protocol
    Then my "bank" balance should have risen by the garbage route pay
    And the garbage truck should be gone

  # --- Recycle: buyer ---------------------------------------------------------

  @world
  Scenario: The recycling buyer quotes two dollars for each of the eight materials
    Given I stand at 1049.84 -3095.6 -39.0 facing 0.0
    Then the recycling buyer should quote 2 for every material

  @world @rejection
  Scenario: The recycling buyer quotes nothing from across the warehouse
    Given I stand at 1073.0 -3102.49 -39.0 facing 0.0
    Then the recycling buyer should refuse to quote

  @world @rejection
  Scenario Outline: The recycling buyer ignores a malformed sale amount
    Given I hold 10 "metalscrap"
    And I stand at 1049.84 -3095.6 -39.0 facing 0.0
    And the recycling buyer should quote 2 for every material
    And I remember my "cash" balance
    And I remember how many "metalscrap" I have
    When I send the recycling buyer a sale of "<amount>" "metalscrap"
    Then my "cash" balance should be unchanged
    And I should have 0 fewer "metalscrap" than before

    Examples:
      | amount     |
      | 0          |
      | -3         |
      | 1.5        |
      | text:abc   |
      | text:      |
      | nil        |
      | true       |

  @world @global
  Scenario Outline: The recycling buyer accepts whole amounts and clamps to what is held
    Given I hold 10 "metalscrap"
    And I stand at 1049.84 -3095.6 -39.0 facing 0.0
    And the recycling buyer should quote 2 for every material
    And I remember my "cash" balance
    And I remember how many "metalscrap" I have
    When I send the recycling buyer a sale of "<amount>" "metalscrap"
    Then my "cash" balance should have increased by <paid>
    And I should have <sold> fewer "metalscrap" than before

    Examples:
      | amount | sold | paid |
      | 1      | 1    | 2    |
      | 4      | 4    | 8    |
      | text:2 | 2    | 4    |
      | 12     | 10   | 20   |

  @world @global
  Scenario: One sale is capped at five hundred units
    Given I hold 300 "copper"
    And I hold 300 "copper"
    And I stand at 1049.84 -3095.6 -39.0 facing 0.0
    And the recycling buyer should quote 2 for every material
    And I remember my "cash" balance
    And I remember how many "copper" I have
    When I send the recycling buyer a sale of "600" "copper"
    Then my "cash" balance should have increased by 1000
    And I should have 500 fewer "copper" than before

  @world @global
  Scenario Outline: The recycling buyer pays two dollars for every listed material
    Given I hold 3 "<item>"
    And I stand at 1049.84 -3095.6 -39.0 facing 0.0
    And the recycling buyer should quote 2 for every material
    And I remember my "cash" balance
    And I remember how many "<item>" I have
    When I send the recycling buyer a sale of "3" "<item>"
    Then my "cash" balance should have increased by 6
    And I should have 3 fewer "<item>" than before

    Examples:
      | item       |
      | metalscrap |
      | plastic    |
      | copper     |
      | rubber     |
      | iron       |
      | aluminum   |
      | steel      |
      | glass      |

  @world @rejection
  Scenario: The recycling buyer does not buy unlisted items
    Given I hold 3 "cryptostick"
    And I stand at 1049.84 -3095.6 -39.0 facing 0.0
    And the recycling buyer should quote 2 for every material
    And I remember my "cash" balance
    And I remember how many "cryptostick" I have
    When I send the recycling buyer a sale of "3" "cryptostick"
    Then my "cash" balance should be unchanged
    And I should have 0 fewer "cryptostick" than before

  @world @rejection
  Scenario: The recycling buyer ignores a sale from across the warehouse
    Given I hold 5 "glass"
    And I stand at 1073.0 -3102.49 -39.0 facing 0.0
    And the recycling buyer should refuse to quote
    And I remember my "cash" balance
    And I remember how many "glass" I have
    When I send the recycling buyer a sale of "5" "glass"
    Then my "cash" balance should be unchanged
    And I should have 0 fewer "glass" than before

  # --- Recycle: packages ------------------------------------------------------

  @world @rejection
  Scenario Outline: A package is not authorised for an invalid pallet
    Given I stand at the first recycling pallet
    And I wait 1500 milliseconds
    When I call the kora_businesses callback "kora_businesses:recycle:pickupPackage" with:
      """
      [<index>]
      """
    Then the kora_businesses callback should answer false

    Examples:
      | index |
      | 0     |
      | 1.5   |
      | "1"   |
      | 999   |
      | -1    |

  @world @rejection
  Scenario: A package is not authorised away from its pallet
    Given I stand at 1049.84 -3095.6 -39.0 facing 0.0
    And I wait 1500 milliseconds
    When I pick up a recycling package from pallet 1
    Then the kora_businesses callback should answer false

  @world @rejection
  Scenario: Only one package is authorised at a time until it is cancelled
    Given I stand at the first recycling pallet
    Then the recycling centre should authorise a package from pallet 1
    When I pick up a recycling package from pallet 1
    Then the kora_businesses callback should answer false
    When I cancel my recycling package
    Then the recycling centre should authorise a package from pallet 1

  @world @rejection
  Scenario: Handing in without a package pays nothing
    Given I remember my recycling materials
    And I stand at 1048.224 -3097.071 -38.999 facing 0.0
    And I wait 1500 milliseconds
    When I hand in my recycling package
    Then my recycling materials should be unchanged

  @world @rejection
  Scenario: A package handed in away from the hand-in point pays nothing
    Given I stand at the first recycling pallet
    And the recycling centre should authorise a package from pallet 1
    And I remember my recycling materials
    When I wait 5500 milliseconds
    And I hand in my recycling package
    Then my recycling materials should be unchanged

  @world @global @slow
  Scenario: A package pays out once, and only after the hand-in time
    Given I stand at the first recycling pallet
    And the recycling centre should authorise a package from pallet 1
    And I carry my recycling package to the hand-in point
    And I remember my recycling materials
    When I hand in my recycling package
    Then my recycling materials should be unchanged
    When I wait 5000 milliseconds
    And I hand in my recycling package
    Then I should have received 1 to 25 recycling materials
    When I remember my recycling materials
    When I hand in my recycling package
    Then my recycling materials should be unchanged

  # --- CCTV, as someone who is not an engineer ------------------------------

  @rejection
  Scenario: The CCTV call-out list is empty for non-engineers
    Given my job is "unemployed" at grade 1
    When I call the kora_businesses callback "kora_businesses:cctv:listCallouts"
    Then the kora_businesses callback should answer an empty list

  @rejection
  Scenario Outline: CCTV engineer actions are refused to non-engineers
    Given my job is "unemployed" at grade 1
    When I call the kora_businesses callback "<callback>" with:
      """
      [<argument>]
      """
    Then the kora_businesses callback should refuse with "You must be an on-duty CCTV engineer."

    Examples:
      | callback                                | argument               |
      | kora_businesses:cctv:laptopData         | 0                      |
      | kora_businesses:cctv:acceptCallout      | "cctv-fft-none"        |
      | kora_businesses:cctv:completeCallout    | "cctv-fft-none"        |
      | kora_businesses:cctv:declineCallout     | "cctv-fft-none"        |
      | kora_businesses:cctv:beginRepairCheck   | { "targetId": "fft" }  |

  @rejection
  Scenario Outline: Finishing a CCTV session that never started is refused
    Given my job is "unemployed" at grade 1
    When I call the kora_businesses callback "<callback>" with:
      """
      [{ "proof": "fft-forged-proof" }]
      """
    Then the kora_businesses callback should refuse with "<reason>"

    Examples:
      | callback                                | reason                         |
      | kora_businesses:cctv:finishHack         | That hacking session expired.  |
      | kora_businesses:cctv:finishRepairCheck  | That repair check expired.     |

  @rejection
  Scenario Outline: A CCTV hack needs a valid target id
    Given my job is "unemployed" at grade 1
    When I call the kora_businesses callback "kora_businesses:cctv:beginHack" with:
      """
      [<argument>]
      """
    Then the kora_businesses callback should refuse with "Invalid CCTV target."

    Examples:
      | argument            |
      | { "targetId": 5 }   |
      | { }                 |
      | "fft-target"        |
      | { "targetId": "fft-target-id-that-is-much-longer-than-the-eighty-character-limit-allowed-by-the-server" } |

  @rejection
  Scenario: A CCTV call-out needs a valid issue
    Given my job is "unemployed" at grade 1
    And I note the number of CCTV call-outs
    When I call the kora_businesses callback "kora_businesses:cctv:requestCallout" with:
      """
      [{ "issue": "fire", "customerType": "business", "business": "unemployed" }]
      """
    Then the kora_businesses callback should refuse with "Choose a valid CCTV issue."
    And the number of CCTV call-outs should be unchanged

  @rejection
  Scenario: A residential CCTV call-out is only for the caller's own home
    Given my job is "unemployed" at grade 1
    And I note the number of CCTV call-outs
    When I request a residential CCTV call-out for another citizen
    Then the kora_businesses callback should refuse with "You are not authorised for that home."
    And the number of CCTV call-outs should be unchanged
