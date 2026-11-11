@kora @kora_diving
Feature: kora_diving coral registry, coral seller and diving gear oxygen rule
  Divers pick coral under water and sell it to the seller on the beach. The
  seller position, coral items and labels come from
  kora_diving/shared/config.lua and locales/en.lua.

  Not covered: filling the gear with an oxygen tube through the usable (the
  client keeps the oxygen level in a file-local with no reset, so a filled tank
  would outlive the scenario and break the empty-gear rule on the next run)
  and putting the suit on (needs a filled tank). The server half of the fill,
  the qb-diving:server:fillOxygen callback, is driven directly. Coral prices
  are random per server start and are not published, so payouts are asserted
  as ranges or as multiples of a price measured in the same scenario. The
  server-side sell and pick validations are driven with the same net events
  the seller option and the coral option send after their progress bars; the
  seller option itself is covered by the targeting scenarios. One scenario
  really picks a coral: it marks that coral as taken for every player for five
  minutes (the resource restores it itself) and is tagged @global. The
  empty-gear scenarios assume the tester has not filled diving gear earlier in
  this game session.

  Background:
    Given resource "kora_diving" is running

  @server
  Scenario: Coral registry is published for every client
    Then the diving coral registry should publish 25 corals with a position and a picked flag

  @rejection
  Scenario: Diving gear with an empty tank asks for an oxygen tube
    Given I hold 1 "diving_gear"
    And I remember how many "diving_gear" I have
    When I use my diving equipment "diving_gear"
    Then I should see a notification containing "You need an oxygen tube to fill your empty diving gear"
    And no progress bar should be running
    And I should have 0 fewer "diving_gear" than before

  # Config.CoralTypes[1] = dendrogyra_coral, price math.random(70, 100) each.
  @world @ui
  Scenario: Seller buys every coral the diver carries
    Given I should carry no coral of my own before visiting the diving seller
    And I hold 2 "dendrogyra_coral"
    And I remember my "cash" balance
    And I face the diving coral seller
    When I target "Sell Coral"
    Then a progress bar labelled "Checking Pockets To Sell Coral" should start
    And the progress bar should finish
    And the diving seller should have paid me between 140 and 200 in cash
    And I should have no "dendrogyra_coral"
    And a money change should have been recorded for "cash"

  @world @ui @rejection
  Scenario: Seller pays nothing to a diver without coral
    Given I should carry no coral of my own before visiting the diving seller
    And I remember my "cash" balance
    And I face the diving coral seller
    When I target "Sell Coral"
    Then a progress bar labelled "Checking Pockets To Sell Coral" should start
    And the progress bar should finish
    And I wait 1500 milliseconds
    And my "cash" balance should be unchanged

  # ---------------------------------------------------------------------------
  # Coral registry
  # ---------------------------------------------------------------------------

  # Config.CoralLocations: 25 entries, published unchanged as GlobalState.Corals.
  @server
  Scenario: Coral registry publishes exactly the configured coral positions in order
    Then the diving coral registry should list every configured coral position

  # ---------------------------------------------------------------------------
  # Coral seller: the server side of the "Sell Coral" option
  # ---------------------------------------------------------------------------

  # Config.CoralTypes: dendrogyra_coral price math.random(70, 100), antipatharia_coral
  # price math.random(50, 70), fixed per server start. The seller buys every piece.
  @world
  Scenario Outline: Seller buys <amount> <coral> at the configured price range
    Given I should carry no coral of my own before visiting the diving seller
    And I hold <amount> "<coral>"
    And I remember my "cash" balance
    And I stand beside the diving coral seller
    When I offer my coral to the diving seller
    Then the diving seller should have paid me between <low> and <high> in cash
    And I should have no "<coral>"
    And a money change should have been recorded for "cash"

    Examples:
      | coral              | amount | low | high |
      | dendrogyra_coral   | 1      | 70  | 100  |
      | dendrogyra_coral   | 5      | 350 | 500  |
      | antipatharia_coral | 1      | 50  | 70   |
      | antipatharia_coral | 7      | 350 | 490  |

  @world
  Scenario: Seller buys both coral types in one visit
    Given I should carry no coral of my own before visiting the diving seller
    And I hold 1 "dendrogyra_coral"
    And I hold 1 "antipatharia_coral"
    And I remember my "cash" balance
    And I stand beside the diving coral seller
    When I offer my coral to the diving seller
    Then the diving seller should have paid me between 120 and 170 in cash
    And I should have no "dendrogyra_coral"
    And I should have no "antipatharia_coral"

  # The price is rolled once at resource start, not per sale.
  @world
  Scenario: Seller pays the same price per coral on every visit
    Given I should carry no coral of my own before visiting the diving seller
    And I stand beside the diving coral seller
    And I hold 1 "dendrogyra_coral"
    And I remember my "cash" balance
    When I offer my coral to the diving seller
    Then I note what the diving seller paid for one coral
    Given I hold 3 "dendrogyra_coral"
    And I remember my "cash" balance
    When I offer my coral to the diving seller
    Then the diving seller should have paid exactly 3 times the noted coral price
    And I should have no "dendrogyra_coral"

  # server/server.lua sellCoral only walks Config.CoralTypes.
  @world
  Scenario: Seller leaves diving gear in the diver's pockets
    Given I should carry no coral of my own before visiting the diving seller
    And I hold 1 "diving_gear"
    And I hold 1 "dendrogyra_coral"
    And I remember how many "diving_gear" I have
    And I remember my "cash" balance
    And I stand beside the diving coral seller
    When I offer my coral to the diving seller
    Then the diving seller should have paid me between 70 and 100 in cash
    And I should have no "dendrogyra_coral"
    And I should have 0 fewer "diving_gear" than before

  @world @rejection
  Scenario: Seller pays nothing when the diver only carries diving gear
    Given I should carry no coral of my own before visiting the diving seller
    And I hold 1 "diving_gear"
    And I remember how many "diving_gear" I have
    And I remember my "cash" balance
    And I stand beside the diving coral seller
    When I offer my coral to the diving seller
    Then my "cash" balance should be unchanged
    And I should have 0 fewer "diving_gear" than before

  # Two sell requests in the same frame: the first takes every coral, so the
  # second finds nothing and the coral is paid for once.
  @world
  Scenario: A doubled sell request pays for the coral only once
    Given I should carry no coral of my own before visiting the diving seller
    And I hold 2 "dendrogyra_coral"
    And I remember my "cash" balance
    And I stand beside the diving coral seller
    When I offer my coral to the diving seller twice at once
    Then the diving seller should have paid me between 140 and 200 in cash
    And I should have no "dendrogyra_coral"

  # server/server.lua sellCoral: Kora.distance.player(src, coords, 10.0), a 3D check.
  @world @rejection
  Scenario: Seller refuses a diver 12 metres away
    Given I should carry no coral of my own before visiting the diving seller
    And I hold 2 "dendrogyra_coral"
    And I remember how many "dendrogyra_coral" I have
    And I remember my "cash" balance
    And I hover 12 metres above the diving coral seller
    And the server should see me 12 metres above the diving coral seller
    And I expect a console error from "kora_diving" containing "Player is too far from the sell location"
    When I offer my coral to the diving seller
    Then my "cash" balance should be unchanged
    And I should have 0 fewer "dendrogyra_coral" than before

  @world
  Scenario: Seller still serves a diver 8 metres away
    Given I should carry no coral of my own before visiting the diving seller
    And I hold 1 "dendrogyra_coral"
    And I remember my "cash" balance
    And I hover 8 metres above the diving coral seller
    And the server should see me 8 metres above the diving coral seller
    When I offer my coral to the diving seller
    Then the diving seller should have paid me between 70 and 100 in cash
    And I should have no "dendrogyra_coral"

  # ---------------------------------------------------------------------------
  # Coral picking: the server side of the "Pick coral" option
  # ---------------------------------------------------------------------------

  @rejection
  Scenario: Pick request without a coral index is refused
    Given I should carry no coral of my own before visiting the diving seller
    And I expect a console error from "kora_diving" containing "Index not provided"
    When I ask to pick diving coral without an index
    Then I wait 1000 milliseconds
    And I should have no "dendrogyra_coral"
    And I should have no "antipatharia_coral"

  @rejection
  Scenario Outline: Pick request for coral number <index> is refused as an invalid index
    Given I should carry no coral of my own before visiting the diving seller
    And I expect a console error from "kora_diving" containing "Invalid Coral Index"
    When I ask to pick diving coral number <index>
    Then I wait 1000 milliseconds
    And I should have no "dendrogyra_coral"
    And I should have no "antipatharia_coral"

    Examples:
      | index |
      | 0     |
      | 26    |
      | -1    |
      | 9999  |

  # Config.CoralLocations is an array: "1" and 1.5 are not keys of it.
  @rejection
  Scenario: Pick request with a text coral index is refused
    Given I should carry no coral of my own before visiting the diving seller
    And I expect a console error from "kora_diving" containing "Invalid Coral Index"
    When I ask to pick diving coral by the text index "1"
    Then I wait 1000 milliseconds
    And I should have no "dendrogyra_coral"
    And I should have no "antipatharia_coral"

  @rejection
  Scenario: Pick request with a fractional coral index is refused
    Given I should carry no coral of my own before visiting the diving seller
    And I expect a console error from "kora_diving" containing "Invalid Coral Index"
    When I ask to pick diving coral by the fractional index 1.5
    Then I wait 1000 milliseconds
    And I should have no "dendrogyra_coral"
    And I should have no "antipatharia_coral"

  # server/server.lua PickCoral: Kora.distance.player(source, coral.coords, 10.0).
  @world @rejection
  Scenario: A coral cannot be picked from the beach
    Given I should carry no coral of my own before visiting the diving seller
    And I note the first unpicked diving coral
    And I stand beside the diving coral seller
    And I expect a console error from "kora_diving" containing "Player is too far from the coral"
    When I ask to pick the first unpicked diving coral from where I stand
    Then I wait 1000 milliseconds
    And the diving coral I noted should still be unpicked
    And I should have no "dendrogyra_coral"
    And I should have no "antipatharia_coral"

  # A real pick: the coral is marked taken for everyone and respawns by itself
  # after five minutes (server/server.lua SetTimeout 1000 * 60 * 5). Reward:
  # dendrogyra_coral 1-5 or antipatharia_coral 2-7. The diver stays under water
  # for a few seconds only and is brought back to the surface by the cleanup.
  @world @global
  Scenario: Picking a coral pays one coral reward and marks it taken until it respawns
    Given I should carry no coral of my own before visiting the diving seller
    And I note the first unpicked diving coral
    And I swim to the first unpicked diving coral
    And the server should see me beside the diving coral I noted
    When I pick the diving coral I swam to
    Then the diving coral I noted should be marked picked
    And I should have picked one diving coral reward
    And I expect a console error from "kora_diving" containing "Coral at this index has already been picked up"
    When I pick the diving coral I swam to
    Then I wait 1000 milliseconds
    And I should still hold only the first diving coral reward

  # ---------------------------------------------------------------------------
  # Oxygen tube: the server half of filling the gear
  # ---------------------------------------------------------------------------

  # server/server.lua: RemoveItem(source, 'diving_fill', 1) == true.
  Scenario: Oxygen fill takes one oxygen tube
    Given I hold 1 "diving_fill"
    And I remember how many "diving_fill" I have
    When I ask the diving server to take an oxygen tube for my gear
    Then the diving server should have accepted the oxygen tube
    And I should have 1 fewer "diving_fill" than before

  @rejection
  Scenario: Oxygen fill is refused without an oxygen tube
    Given I should have no "diving_fill"
    When I ask the diving server to take an oxygen tube for my gear
    Then the diving server should have refused the oxygen tube

  Scenario: Oxygen fill takes only one tube when the diver carries several
    Given I hold 2 "diving_fill"
    And I remember how many "diving_fill" I have
    When I ask the diving server to take an oxygen tube for my gear
    Then the diving server should have accepted the oxygen tube
    And I should have 1 fewer "diving_fill" than before

  # ---------------------------------------------------------------------------
  # Diving gear: client rules
  # ---------------------------------------------------------------------------

  # client/client.lua UseGear checks the empty tank before the vehicle rule.
  @rejection
  Scenario: Empty diving gear asks for an oxygen tube even in a vehicle
    Given I hold 1 "diving_gear"
    And I remember how many "diving_gear" I have
    And I am driving a temporary "blista"
    When I use my diving equipment "diving_gear"
    Then I should see a notification containing "You need an oxygen tube to fill your empty diving gear"
    And I should not see a notification containing "You need to be standing up to put on the diving gear"
    And no progress bar should be running
    And I should have 0 fewer "diving_gear" than before
